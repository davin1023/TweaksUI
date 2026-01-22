-- TweaksUI Import Module
-- Handles importing/exporting settings and CMT compatibility

local ADDON_NAME, TweaksUI = ...

TweaksUI.Import = {}
local Import = TweaksUI.Import

-- ============================================================================
-- SERIALIZATION HELPERS (compatible with CMT format)
-- ============================================================================

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
        -- Check if it's an array
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
            -- Serialize as array
            for i = 1, maxIndex do
                table.insert(parts, serializeValue(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            -- Serialize as object
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
    -- Skip whitespace
    while pos <= #str and str:sub(pos, pos):match("%s") do
        pos = pos + 1
    end
    
    if pos > #str then return nil, pos end
    
    local char = str:sub(pos, pos)
    
    -- String
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
    
    -- Number
    if char:match("[%-0-9]") then
        local numStr = str:match("^%-?[0-9]+%.?[0-9]*", pos)
        if numStr then
            return tonumber(numStr), pos + #numStr
        end
    end
    
    -- Boolean/null
    if str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    end
    
    -- Array
    if char == "[" then
        local result = {}
        pos = pos + 1
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do
                pos = pos + 1
            end
            if str:sub(pos, pos) == "]" then
                return result, pos + 1
            end
            local val, newPos = deserializeValue(str, pos)
            if newPos == pos then break end
            table.insert(result, val)
            pos = newPos
            while pos <= #str and (str:sub(pos, pos):match("%s") or str:sub(pos, pos) == ",") do
                pos = pos + 1
            end
        end
        return result, pos
    end
    
    -- Object
    if char == "{" then
        local result = {}
        pos = pos + 1
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do
                pos = pos + 1
            end
            if str:sub(pos, pos) == "}" then
                return result, pos + 1
            end
            local key, newPos = deserializeValue(str, pos)
            if not key then break end
            pos = newPos
            while pos <= #str and (str:sub(pos, pos):match("%s") or str:sub(pos, pos) == ":") do
                pos = pos + 1
            end
            local val
            val, pos = deserializeValue(str, pos)
            result[key] = val
            while pos <= #str and (str:sub(pos, pos):match("%s") or str:sub(pos, pos) == ",") do
                pos = pos + 1
            end
        end
        return result, pos
    end
    
    return nil, pos
end

-- ============================================================================
-- CMT STRING PARSING
-- ============================================================================

-- Decode a CMT export string (CMT1: prefix)
function Import:DecodeCMTString(encoded)
    if not encoded or type(encoded) ~= "string" then
        return nil, "Invalid input: expected string"
    end
    
    -- Check for CMT1: prefix
    if not encoded:match("^CMT1:") then
        return nil, "Invalid format: expected 'CMT1:' prefix"
    end
    
    local data = encoded:sub(6) -- Remove "CMT1:" prefix
    
    -- Try to decode with LibDeflate if available
    local json
    local LibDeflate = LibStub and LibStub:GetLibrary("LibDeflate", true)
    
    if LibDeflate then
        local decoded = LibDeflate:DecodeForPrint(data)
        if decoded then
            local decompressed = LibDeflate:DecompressDeflate(decoded)
            json = decompressed or decoded
        else
            json = data
        end
    else
        -- No LibDeflate, try raw
        json = data
    end
    
    if not json or json == "" then
        return nil, "Failed to decode data"
    end
    
    -- Parse JSON
    local parsed, _ = deserializeValue(json, 1)
    
    if not parsed then
        return nil, "Failed to parse data structure"
    end
    
    return parsed, nil
end

-- ============================================================================
-- CMT TO TWEAKSUI CONVERSION
-- ============================================================================

-- Convert CMT export data to TweaksUI cooldowns format
function Import:ConvertCMTData(cmtData)
    if not cmtData then
        return nil, "No data to convert"
    end
    
    local result = {
        trackers = {},
        _meta = {
            importedFrom = "CMT",
            importedAt = date("%Y-%m-%d %H:%M:%S"),
            cmtVersion = cmtData.version,
            originalProfileName = cmtData.profileName or cmtData._profileName,
        },
    }
    
    -- Copy tracker settings
    if cmtData.trackers then
        for trackerKey, trackerSettings in pairs(cmtData.trackers) do
            result.trackers[trackerKey] = {}
            for k, v in pairs(trackerSettings) do
                if type(v) == "table" then
                    result.trackers[trackerKey][k] = CopyTable(v)
                else
                    result.trackers[trackerKey][k] = v
                end
            end
        end
    end
    
    return result, nil
end

-- ============================================================================
-- IMPORT FROM CMT STRING
-- ============================================================================

-- Import a CMT export string
-- Returns: success, message, profileName
function Import:ImportCMTString(exportString, targetProfileName)
    -- Decode the string
    local cmtData, decodeErr = self:DecodeCMTString(exportString)
    if not cmtData then
        return false, "Decode error: " .. (decodeErr or "unknown"), nil
    end
    
    -- Convert to our format
    local converted, convertErr = self:ConvertCMTData(cmtData)
    if not converted then
        return false, "Conversion error: " .. (convertErr or "unknown"), nil
    end
    
    -- Determine profile name
    local profileName = targetProfileName
    if not profileName or profileName == "" then
        profileName = cmtData.profileName or cmtData._profileName or "CMT Import"
    end
    
    -- Make sure profile name is unique
    local baseName = profileName
    local counter = 1
    while TweaksUI.Database:ProfileExists(profileName) do
        profileName = baseName .. " (" .. counter .. ")"
        counter = counter + 1
    end
    
    -- Create the profile
    if not TweaksUI.Database:CreateProfile(profileName) then
        return false, "Failed to create profile", nil
    end
    
    -- Get the new profile and populate cooldowns
    local profile = TweaksUI.Database:GetProfile(profileName)
    if not profile then
        return false, "Failed to access new profile", nil
    end
    
    -- Store the converted tracker settings in the cooldowns section
    profile.cooldowns = profile.cooldowns or {}
    profile.cooldowns.imported = converted
    profile._meta = converted._meta
    
    -- Also apply to CMT_DB if it exists (for immediate effect)
    if CMT_DB and CMT_DB.profiles then
        CMT_DB.profiles[profileName] = CMT_DB.profiles[profileName] or {}
        if converted.trackers then
            for trackerKey, settings in pairs(converted.trackers) do
                CMT_DB.profiles[profileName][trackerKey] = settings
            end
        end
    end
    
    return true, "Successfully imported as '" .. profileName .. "'", profileName
end

-- ============================================================================
-- TWEAKSUI EXPORT (new format)
-- ============================================================================

local TUI_EXPORT_VERSION = "TUI1"

-- Export ALL module settings for the current profile
function Import:ExportProfile()
    local charKey = TweaksUI.Database:GetCharacterKey()
    local charDb = TweaksUI.Database:GetCharacterDB()
    
    local exportData = {
        version = TweaksUI.VERSION or "1.0.0",
        profileName = charKey,  -- Use character name as profile name
        exportType = "full",  -- Indicates all modules
        modules = {},
    }
    
    -- Export settings from character database
    if charDb and charDb.settings then
        for moduleId, moduleSettings in pairs(charDb.settings) do
            if type(moduleSettings) == "table" then
                exportData.modules[moduleId] = CopyTable(moduleSettings)
            end
        end
    end
    
    -- Also export CMT_DB.profiles data if available (cooldowns module uses this)
    -- Use "Default" profile as fallback since we no longer have profile names
    if CMT_DB and CMT_DB.profiles then
        local cmtProfile = CMT_DB.profiles[charKey] or CMT_DB.profiles["Default"]
        if cmtProfile then
            exportData.cooldowns_cmt = {}
            for trackerKey, settings in pairs(cmtProfile) do
                if type(settings) == "table" then
                    exportData.cooldowns_cmt[trackerKey] = CopyTable(settings)
                end
            end
        end
    end
    
    local json = serializeValue(exportData)
    
    -- Compress if LibDeflate is available
    local LibDeflate = LibStub and LibStub:GetLibrary("LibDeflate", true)
    local encoded
    if LibDeflate then
        local compressed = LibDeflate:CompressDeflate(json)
        encoded = LibDeflate:EncodeForPrint(compressed)
    else
        encoded = json
    end
    
    return TUI_EXPORT_VERSION .. ":" .. encoded, nil
end

-- Export profile as uncompressed JSON (easier for debugging/sharing)
function Import:ExportProfileRaw()
    local charKey = TweaksUI.Database:GetCharacterKey()
    local charDb = TweaksUI.Database:GetCharacterDB()
    
    local exportData = {
        version = TweaksUI.VERSION or "1.0.0",
        profileName = charKey,
        exportType = "full",
        modules = {},
    }
    
    -- Export settings from character database
    if charDb and charDb.settings then
        for moduleId, moduleSettings in pairs(charDb.settings) do
            if type(moduleSettings) == "table" then
                exportData.modules[moduleId] = CopyTable(moduleSettings)
            end
        end
    end
    
    -- Also export CMT_DB.profiles data if available
    if CMT_DB and CMT_DB.profiles then
        local cmtProfile = CMT_DB.profiles[charKey] or CMT_DB.profiles["Default"]
        if cmtProfile then
            exportData.cooldowns_cmt = {}
            for trackerKey, settings in pairs(cmtProfile) do
                if type(settings) == "table" then
                    exportData.cooldowns_cmt[trackerKey] = CopyTable(settings)
                end
            end
        end
    end
    
    -- Return uncompressed JSON with TUIRAW prefix
    local json = serializeValue(exportData)
    return "TUIRAW:" .. json, nil
end

-- Export cooldowns settings only (for backward compatibility)
function Import:ExportCooldowns()
    local charKey = TweaksUI.Database:GetCharacterKey()
    
    local exportData = {
        version = TweaksUI.VERSION or "1.0.0",
        profileName = charKey,
        exportType = "cooldowns",
        trackers = {},
    }
    
    -- Export from CMT_DB.profiles if available
    if CMT_DB and CMT_DB.profiles then
        local cmtProfile = CMT_DB.profiles[charKey] or CMT_DB.profiles["Default"]
        if cmtProfile then
            for trackerKey, settings in pairs(cmtProfile) do
                if type(settings) == "table" then
                    exportData.trackers[trackerKey] = CopyTable(settings)
                end
            end
        end
    end
    
    local json = serializeValue(exportData)
    
    local LibDeflate = LibStub and LibStub:GetLibrary("LibDeflate", true)
    local encoded
    if LibDeflate then
        local compressed = LibDeflate:CompressDeflate(json)
        encoded = LibDeflate:EncodeForPrint(compressed)
    else
        encoded = json
    end
    
    return TUI_EXPORT_VERSION .. ":" .. encoded, nil
end

-- ============================================================================
-- IMPORT TWEAKSUI STRING
-- ============================================================================

function Import:ImportTUIString(exportString, targetProfileName)
    if not exportString or not exportString:match("^" .. TUI_EXPORT_VERSION .. ":") then
        return false, "Invalid format: expected TweaksUI export string", nil
    end
    
    local data = exportString:sub(#TUI_EXPORT_VERSION + 2)
    
    local LibDeflate = LibStub and LibStub:GetLibrary("LibDeflate", true)
    local json
    if LibDeflate then
        local decoded = LibDeflate:DecodeForPrint(data)
        if decoded then
            json = LibDeflate:DecompressDeflate(decoded) or decoded
        else
            json = data
        end
    else
        json = data
    end
    
    local parsed, _ = deserializeValue(json, 1)
    if not parsed then
        return false, "Failed to parse export data", nil
    end
    
    -- Get character database
    local charDb = TweaksUI.Database:GetCharacterDB()
    if not charDb then
        return false, "Failed to access character database", nil
    end
    
    -- Ensure settings table exists
    charDb.settings = charDb.settings or {}
    
    -- Import module settings directly into character settings
    local importedCount = 0
    if parsed.modules then
        for moduleId, moduleSettings in pairs(parsed.modules) do
            if type(moduleSettings) == "table" then
                charDb.settings[moduleId] = CopyTable(moduleSettings)
                importedCount = importedCount + 1
            end
        end
    end
    
    -- Import legacy General settings (from older exports that stored outside profile)
    if parsed.general then
        charDb.settings[TweaksUI.MODULE_IDS.GENERAL] = CopyTable(parsed.general)
        importedCount = importedCount + 1
    end
    
    -- Import legacy CastBars settings (from older exports that stored outside profile)
    if parsed.castBars then
        charDb.settings[TweaksUI.MODULE_IDS.CAST_BARS] = CopyTable(parsed.castBars)
        importedCount = importedCount + 1
    end
    
    -- Import cooldowns CMT data if present
    if parsed.cooldowns_cmt and CMT_DB then
        CMT_DB.profiles = CMT_DB.profiles or {}
        CMT_DB.profiles["Default"] = CMT_DB.profiles["Default"] or {}
        for trackerKey, settings in pairs(parsed.cooldowns_cmt) do
            if type(settings) == "table" then
                CMT_DB.profiles["Default"][trackerKey] = CopyTable(settings)
            end
        end
    end
    
    -- Fire settings changed event
    TweaksUI.Events:Fire(TweaksUI.EVENTS.SETTINGS_CHANGED, nil, nil, nil)
    
    local charKey = TweaksUI.Database:GetCharacterKey()
    return true, "Successfully imported " .. importedCount .. " modules to " .. charKey, charKey
end

-- ============================================================================
-- AUTO-DETECT AND IMPORT
-- ============================================================================

function Import:AutoImport(exportString, targetProfileName)
    if not exportString or exportString == "" then
        return false, "Empty import string", nil
    end
    
    -- Trim whitespace
    exportString = exportString:match("^%s*(.-)%s*$")
    
    if exportString:match("^TUI1:") then
        return self:ImportTUIString(exportString, targetProfileName)
    elseif exportString:match("^TUIRAW:") then
        return self:ImportTUIRawString(exportString, targetProfileName)
    elseif exportString:match("^CMT1:") then
        return self:ImportCMTString(exportString, targetProfileName)
    else
        return false, "Unrecognized format. Expected 'TUI1:', 'TUIRAW:', or 'CMT1:' prefix.", nil
    end
end

-- Import uncompressed/raw TUI string
function Import:ImportTUIRawString(exportString, targetProfileName)
    if not exportString or not exportString:match("^TUIRAW:") then
        return false, "Invalid format: expected TUIRAW: prefix", nil
    end
    
    local json = exportString:sub(8)  -- Skip "TUIRAW:"
    
    local parsed, _ = deserializeValue(json, 1)
    if not parsed then
        return false, "Failed to parse raw export data", nil
    end
    
    -- Get character database
    local charDb = TweaksUI.Database:GetCharacterDB()
    if not charDb then
        return false, "Failed to access character database", nil
    end
    
    -- Ensure settings table exists
    charDb.settings = charDb.settings or {}
    
    -- Import module settings directly into character settings
    local importedCount = 0
    if parsed.modules then
        for moduleId, moduleSettings in pairs(parsed.modules) do
            if type(moduleSettings) == "table" then
                charDb.settings[moduleId] = CopyTable(moduleSettings)
                importedCount = importedCount + 1
            end
        end
    end
    
    -- Import cooldowns CMT data if present
    if parsed.cooldowns_cmt and CMT_DB then
        CMT_DB.profiles = CMT_DB.profiles or {}
        CMT_DB.profiles["Default"] = CMT_DB.profiles["Default"] or {}
        for trackerKey, settings in pairs(parsed.cooldowns_cmt) do
            if type(settings) == "table" then
                CMT_DB.profiles["Default"][trackerKey] = CopyTable(settings)
            end
        end
    end
    
    -- Fire settings changed event
    TweaksUI.Events:Fire(TweaksUI.EVENTS.SETTINGS_CHANGED, nil, nil, nil)
    
    local charKey = TweaksUI.Database:GetCharacterKey()
    return true, "Successfully imported " .. importedCount .. " modules to " .. charKey, charKey
end

-- Alias for backwards compatibility and Settings panel
function Import:ImportProfile(exportString)
    return self:AutoImport(exportString)
end

-- ============================================================================
-- IMPORT UI
-- ============================================================================

local importFrame = nil
local exportFrame = nil

function Import:ShowImportDialog()
    if not importFrame then
        importFrame = CreateFrame("Frame", "TweaksUI_ImportFrame", UIParent, "BasicFrameTemplateWithInset")
        importFrame:SetSize(500, 420)
        importFrame:SetPoint("CENTER")
        importFrame:SetMovable(true)
        importFrame:EnableMouse(true)
        importFrame:RegisterForDrag("LeftButton")
        importFrame:SetScript("OnDragStart", importFrame.StartMoving)
        importFrame:SetScript("OnDragStop", importFrame.StopMovingOrSizing)
        importFrame:SetFrameStrata("DIALOG")
        
        importFrame.title = importFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        importFrame.title:SetPoint("TOP", 0, -5)
        importFrame.title:SetText("Import Settings")
        
        local info = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        info:SetPoint("TOPLEFT", 15, -30)
        info:SetWidth(470)
        info:SetJustifyH("LEFT")
        info:SetText("Paste a TweaksUI or CMT export string below:")
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, importFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 15, -55)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 80)
        
        -- Create a background for the edit area
        local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.3)
        
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(440)
        editBox:SetHeight(180)
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(5, 5, 5, 5)
        editBox:EnableMouse(true)
        editBox:SetScript("OnEscapePressed", function() importFrame:Hide() end)
        editBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
        scrollFrame:SetScrollChild(editBox)
        importFrame.editBox = editBox
        
        local nameLabel = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("BOTTOMLEFT", 15, 55)
        nameLabel:SetText("Profile name (optional):")
        
        local nameBox = CreateFrame("EditBox", nil, importFrame, "InputBoxTemplate")
        nameBox:SetSize(200, 20)
        nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
        nameBox:SetAutoFocus(false)
        importFrame.nameBox = nameBox
        
        local importBtn = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
        importBtn:SetSize(100, 24)
        importBtn:SetPoint("BOTTOMRIGHT", -120, 15)
        importBtn:SetText("Import")
        importBtn:SetScript("OnClick", function()
            local importString = importFrame.editBox:GetText()
            local profileName = importFrame.nameBox:GetText()
            
            local success, msg, newName = Import:AutoImport(importString, profileName)
            
            if success then
                TweaksUI:Print(msg)
                importFrame:Hide()
                
                if newName then
                    StaticPopupDialogs["TWEAKSUI_SWITCH_PROFILE"] = {
                        text = "Switch to imported profile '" .. newName .. "'?",
                        button1 = "Yes",
                        button2 = "No",
                        OnAccept = function()
                            TweaksUI.Database:SetProfile(newName)
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                    }
                    StaticPopup_Show("TWEAKSUI_SWITCH_PROFILE")
                end
            else
                TweaksUI:PrintError("Import failed: " .. msg)
            end
        end)
        
        local cancelBtn = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
        cancelBtn:SetSize(100, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -15, 15)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() importFrame:Hide() end)
    end
    
    importFrame.editBox:SetText("")
    importFrame.nameBox:SetText("")
    importFrame:Show()
    importFrame.editBox:SetFocus()
end

function Import:ShowExportDialog()
    local exportString, err = self:ExportProfile()
    if not exportString then
        TweaksUI:PrintError("Export failed: " .. (err or "unknown error"))
        return
    end
    
    if not exportFrame then
        exportFrame = CreateFrame("Frame", "TweaksUI_ExportFrame", UIParent, "BasicFrameTemplateWithInset")
        exportFrame:SetSize(500, 300)
        exportFrame:SetPoint("CENTER")
        exportFrame:SetMovable(true)
        exportFrame:EnableMouse(true)
        exportFrame:RegisterForDrag("LeftButton")
        exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
        exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
        exportFrame:SetFrameStrata("DIALOG")
        
        exportFrame.title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        exportFrame.title:SetPoint("TOP", 0, -5)
        exportFrame.title:SetText("Export Settings")
        
        local info = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        info:SetPoint("TOPLEFT", 15, -30)
        info:SetWidth(470)
        info:SetJustifyH("LEFT")
        info:SetText("Copy the string below to share your settings:")
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 15, -55)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 50)
        
        -- Create a background for the edit area
        local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.3)
        
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(440)
        editBox:SetHeight(200)
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(5, 5, 5, 5)
        editBox:EnableMouse(true)
        editBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
        editBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
        scrollFrame:SetScrollChild(editBox)
        exportFrame.editBox = editBox
        
        local closeBtn = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
        closeBtn:SetSize(100, 24)
        closeBtn:SetPoint("BOTTOM", 0, 15)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function() exportFrame:Hide() end)
    end
    
    local profileName = TweaksUI.Database:GetProfileName()
    exportFrame.title:SetText("Export Profile: " .. profileName)
    exportFrame.editBox:SetText(exportString)
    exportFrame:Show()
    exportFrame.editBox:SetFocus()
    exportFrame.editBox:HighlightText()
end

-- ============================================================================
-- EXPORT ALL MODULES
-- ============================================================================

local EXPORT_ALL_VERSION = "TUIALL1"

-- List of modules to export (add new modules here as they're completed)
local EXPORTABLE_MODULES = {
    { id = "cooldowns", name = "Cooldowns" },
    { id = "chat", name = "Chat" },
    { id = "unitFrames", name = "Unit Frames" },
    { id = "personalResources", name = "Personal Resources" },
    { id = "castBars", name = "Cast Bars" },
    { id = "nameplates", name = "Nameplates" },
    { id = "actionBars", name = "Action Bars" },
    { id = "general", name = "General" },
}

function Import:ExportAllModules()
    local allSettings = {
        _meta = {
            version = EXPORT_ALL_VERSION,
            addonVersion = TweaksUI.VERSION,
            exportedAt = date("%Y-%m-%d %H:%M:%S"),
            profileName = TweaksUI.Database:GetProfileName(),
        },
        modules = {},
        moduleStates = {},
    }
    
    -- Get current profile
    local profile = TweaksUI.Database:GetProfile()
    if not profile then
        return nil, "No active profile"
    end
    
    -- Keys to exclude from export (runtime data, not settings)
    local EXCLUDED_KEYS = {
        chat = {
            chatHistory = true,  -- Don't export chat history, just settings
        },
    }
    
    -- Deep copy function that can filter keys
    local function FilteredCopy(orig, excludeKeys)
        if type(orig) ~= "table" then
            return orig
        end
        local copy = {}
        for k, v in pairs(orig) do
            if not (excludeKeys and excludeKeys[k]) then
                if type(v) == "table" then
                    copy[k] = FilteredCopy(v, nil)  -- Only filter top-level keys
                else
                    copy[k] = v
                end
            end
        end
        return copy
    end
    
    -- Export each module's settings
    for _, moduleInfo in ipairs(EXPORTABLE_MODULES) do
        local moduleId = moduleInfo.id
        local moduleSettings = nil
        
        -- Try to get settings from module's GetSettings function first (ensures full merged settings)
        -- Must get module at runtime, not at file load time
        local moduleObj = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(moduleId)
        
        if moduleObj and moduleObj.GetSettings then
            local success, result = pcall(function() return moduleObj:GetSettings() end)
            if success and result then
                moduleSettings = result
            end
        end
        
        -- Fall back to database
        if not moduleSettings then
            moduleSettings = profile[moduleId]
        end
        
        if moduleSettings then
            -- Apply filtering for specific modules
            local excludeKeys = EXCLUDED_KEYS[moduleId]
            if excludeKeys then
                allSettings.modules[moduleId] = FilteredCopy(moduleSettings, excludeKeys)
            else
                allSettings.modules[moduleId] = FilteredCopy(moduleSettings, nil)
            end
        end
        -- Also save whether module is enabled
        allSettings.moduleStates[moduleId] = TweaksUI.Database:IsModuleEnabled(moduleId)
    end
    
    -- Serialize
    local json = serializeValue(allSettings)
    
    -- Compress if LibDeflate available
    local LibDeflate = LibStub and LibStub:GetLibrary("LibDeflate", true)
    local encoded
    if LibDeflate then
        local compressed = LibDeflate:CompressDeflate(json)
        encoded = LibDeflate:EncodeForPrint(compressed)
    else
        encoded = json
    end
    
    return EXPORT_ALL_VERSION .. ":" .. encoded, nil
end

function Import:ImportAllModules(exportString)
    if not exportString or exportString == "" then
        return false, "Empty import string"
    end
    
    -- Trim whitespace
    exportString = exportString:match("^%s*(.-)%s*$")
    
    -- Check for TUIALL1: prefix
    if not exportString:match("^" .. EXPORT_ALL_VERSION .. ":") then
        return false, "Invalid format: expected '" .. EXPORT_ALL_VERSION .. ":' prefix"
    end
    
    local data = exportString:sub(#EXPORT_ALL_VERSION + 2)
    
    -- Decompress if needed
    local LibDeflate = LibStub and LibStub:GetLibrary("LibDeflate", true)
    local json
    if LibDeflate then
        local decoded = LibDeflate:DecodeForPrint(data)
        if decoded then
            json = LibDeflate:DecompressDeflate(decoded) or decoded
        else
            json = data
        end
    else
        json = data
    end
    
    -- Parse
    local parsed, _ = deserializeValue(json, 1)
    if not parsed then
        return false, "Failed to parse export data"
    end
    
    -- Validate structure
    if not parsed.modules or not parsed._meta then
        return false, "Invalid export data structure"
    end
    
    -- Deep copy function
    local function DeepCopy(orig)
        if type(orig) ~= "table" then
            return orig
        end
        local copy = {}
        for k, v in pairs(orig) do
            copy[k] = DeepCopy(v)
        end
        return copy
    end
    
    local importedCount = 0
    local importedModules = {}
    
    -- Keys to preserve during import (runtime data that shouldn't be overwritten)
    local PRESERVED_KEYS = {
        chat = {
            chatHistory = true,  -- Don't overwrite existing chat history
        },
    }
    
    for moduleId, moduleSettings in pairs(parsed.modules) do
        local preserveKeys = PRESERVED_KEYS[moduleId]
        
        -- Deep copy the settings to avoid reference issues
        local importedSettings = DeepCopy(moduleSettings)
        
        if preserveKeys then
            -- Get existing settings to preserve certain keys
            local existingSettings = TweaksUI.Database:GetModuleSettings(moduleId)
            if existingSettings then
                for key, _ in pairs(preserveKeys) do
                    if existingSettings[key] ~= nil then
                        importedSettings[key] = existingSettings[key]
                    end
                end
            end
        end
        
        -- Use SetModuleSettings to ensure proper storage in database
        TweaksUI.Database:SetModuleSettings(moduleId, importedSettings)
        
        -- Some modules use TweaksUI_DB directly - also write there
        if moduleId == "castBars" and TweaksUI_DB then
            TweaksUI_DB.CastBars = DeepCopy(importedSettings)
        end
        
        -- Try to call module's ImportSettings if it exists
        local moduleObj = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(moduleId)
        if moduleObj and moduleObj.ImportSettings then
            pcall(function() moduleObj:ImportSettings(importedSettings) end)
        end
        
        importedCount = importedCount + 1
        table.insert(importedModules, moduleId)
    end
    
    -- Optionally restore module enabled states
    if parsed.moduleStates then
        for moduleId, enabled in pairs(parsed.moduleStates) do
            TweaksUI.Database:SetModuleEnabled(moduleId, enabled)
        end
    end
    
    -- Notify modules to refresh
    TweaksUI.Events:Fire(TweaksUI.EVENTS.PROFILE_CHANGED, TweaksUI.Database:GetProfileName())
    
    -- Also notify each module individually if they have an OnProfileChanged handler
    for _, moduleId in ipairs(importedModules) do
        local moduleObj = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(moduleId)
        if moduleObj and moduleObj.OnProfileChanged then
            pcall(function() moduleObj:OnProfileChanged(TweaksUI.Database:GetProfileName()) end)
        end
    end
    
    local moduleList = table.concat(importedModules, ", ")
    return true, string.format("Imported %d modules: %s", importedCount, moduleList)
end

-- Export All UI
local exportAllFrame = nil
local importAllFrame = nil

function Import:ShowExportAllDialog()
    local exportString, err = self:ExportAllModules()
    
    if not exportString then
        TweaksUI:PrintError("Export All failed: " .. (err or "unknown error"))
        return
    end
    
    if not exportAllFrame then
        exportAllFrame = CreateFrame("Frame", "TweaksUI_ExportAllFrame", UIParent, "BasicFrameTemplateWithInset")
        exportAllFrame:SetSize(550, 350)
        exportAllFrame:SetPoint("CENTER")
        exportAllFrame:SetMovable(true)
        exportAllFrame:EnableMouse(true)
        exportAllFrame:RegisterForDrag("LeftButton")
        exportAllFrame:SetScript("OnDragStart", exportAllFrame.StartMoving)
        exportAllFrame:SetScript("OnDragStop", exportAllFrame.StopMovingOrSizing)
        exportAllFrame:SetFrameStrata("DIALOG")
        
        exportAllFrame.title = exportAllFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        exportAllFrame.title:SetPoint("TOP", 0, -5)
        exportAllFrame.title:SetText("Export All Module Settings")
        
        local info = exportAllFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        info:SetPoint("TOPLEFT", 15, -30)
        info:SetWidth(520)
        info:SetJustifyH("LEFT")
        info:SetText("Copy the string below to share all your module settings:")
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, exportAllFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 15, -55)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 50)
        
        -- Create a background for the edit area
        local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.3)
        
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(490)
        editBox:SetHeight(250)
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(5, 5, 5, 5)
        editBox:EnableMouse(true)
        editBox:SetScript("OnEscapePressed", function() exportAllFrame:Hide() end)
        editBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
        scrollFrame:SetScrollChild(editBox)
        exportAllFrame.editBox = editBox
        
        local closeBtn = CreateFrame("Button", nil, exportAllFrame, "UIPanelButtonTemplate")
        closeBtn:SetSize(100, 24)
        closeBtn:SetPoint("BOTTOM", 0, 15)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function() exportAllFrame:Hide() end)
    end
    
    local profileName = TweaksUI.Database:GetProfileName()
    exportAllFrame.title:SetText("Export All: " .. profileName)
    exportAllFrame.editBox:SetText(exportString)
    exportAllFrame:Show()
    exportAllFrame.editBox:SetFocus()
    exportAllFrame.editBox:HighlightText()
end

function Import:ShowImportAllDialog()
    if not importAllFrame then
        importAllFrame = CreateFrame("Frame", "TweaksUI_ImportAllFrame", UIParent, "BasicFrameTemplateWithInset")
        importAllFrame:SetSize(550, 400)
        importAllFrame:SetPoint("CENTER")
        importAllFrame:SetMovable(true)
        importAllFrame:EnableMouse(true)
        importAllFrame:RegisterForDrag("LeftButton")
        importAllFrame:SetScript("OnDragStart", importAllFrame.StartMoving)
        importAllFrame:SetScript("OnDragStop", importAllFrame.StopMovingOrSizing)
        importAllFrame:SetFrameStrata("DIALOG")
        
        importAllFrame.title = importAllFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        importAllFrame.title:SetPoint("TOP", 0, -5)
        importAllFrame.title:SetText("Import All Module Settings")
        
        local info = importAllFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        info:SetPoint("TOPLEFT", 15, -30)
        info:SetWidth(520)
        info:SetJustifyH("LEFT")
        info:SetText("Paste a TweaksUI 'Export All' string below:\n|cffff8800Warning: This will replace ALL module settings in your current profile!|r")
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, importAllFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 15, -70)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 50)
        
        -- Create a background for the edit area
        local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.3)
        
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(490)
        editBox:SetHeight(280)
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(5, 5, 5, 5)
        editBox:EnableMouse(true)
        editBox:SetScript("OnEscapePressed", function() importAllFrame:Hide() end)
        editBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
        scrollFrame:SetScrollChild(editBox)
        importAllFrame.editBox = editBox
        
        local importBtn = CreateFrame("Button", nil, importAllFrame, "UIPanelButtonTemplate")
        importBtn:SetSize(100, 24)
        importBtn:SetPoint("BOTTOMRIGHT", -120, 15)
        importBtn:SetText("Import")
        importBtn:SetScript("OnClick", function()
            local importString = importAllFrame.editBox:GetText()
            local success, msg = Import:ImportAllModules(importString)
            
            if success then
                TweaksUI:Print("|cff00ff00Import successful:|r " .. msg)
                importAllFrame:Hide()
                
                -- Suggest reload
                StaticPopupDialogs["TWEAKSUI_RELOAD_AFTER_IMPORT"] = {
                    text = "Settings imported successfully. Reload UI to apply all changes?",
                    button1 = "Reload Now",
                    button2 = "Later",
                    OnAccept = function()
                        ReloadUI()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                }
                StaticPopup_Show("TWEAKSUI_RELOAD_AFTER_IMPORT")
            else
                TweaksUI:PrintError("Import failed: " .. msg)
            end
        end)
        
        local cancelBtn = CreateFrame("Button", nil, importAllFrame, "UIPanelButtonTemplate")
        cancelBtn:SetSize(100, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -15, 15)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() importAllFrame:Hide() end)
    end
    
    importAllFrame.editBox:SetText("")
    importAllFrame:Show()
    importAllFrame.editBox:SetFocus()
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

-- These will be registered by Main.lua or Settings.lua
function Import:RegisterSlashCommands()
    -- /tui import
    -- /tui export
    -- Handled in Main.lua
end
