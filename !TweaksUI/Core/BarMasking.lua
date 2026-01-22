-- ============================================================================
-- TweaksUI: BarMasking
-- Bar shape masking system - rounded, pill, arrow, angled ends
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

local BarMasking = {}
TweaksUI.BarMasking = BarMasking

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local TEXTURE_PATH = "Interface\\AddOns\\!TweaksUI\\Media\\Textures\\Masks\\"

-- Available mask shapes
BarMasking.SHAPES = {
    NONE = "none",
    ROUNDED = "rounded",
    PILL = "pill",
    ARROW = "arrow",
    ANGLE45_UP = "angle45_up",      -- /\ slants upward at ends
    ANGLE45_DOWN = "angle45_down",  -- \/ slants downward at ends
    ANGLE22_UP = "angle22_up",      -- /\ gentle upward slant
    ANGLE22_DOWN = "angle22_down",  -- \/ gentle downward slant
    CHEVRON = "chevron",
}

-- Display names for UI
BarMasking.SHAPE_NAMES = {
    [BarMasking.SHAPES.NONE] = "Square (None)",
    [BarMasking.SHAPES.ROUNDED] = "Rounded",
    [BarMasking.SHAPES.PILL] = "Pill",
    [BarMasking.SHAPES.ARROW] = "Arrow",
    [BarMasking.SHAPES.ANGLE45_UP] = "Angle 45° Up",
    [BarMasking.SHAPES.ANGLE45_DOWN] = "Angle 45° Down",
    [BarMasking.SHAPES.ANGLE22_UP] = "Angle 22° Up",
    [BarMasking.SHAPES.ANGLE22_DOWN] = "Angle 22° Down",
    [BarMasking.SHAPES.CHEVRON] = "Chevron",
}

-- Mask texture paths (both ends shaped - mirrored)
-- Each texture has both ends shaped symmetrically
local MASK_TEXTURES = {
    [BarMasking.SHAPES.ROUNDED] = TEXTURE_PATH .. "Mask_Rounded",
    [BarMasking.SHAPES.PILL] = TEXTURE_PATH .. "Mask_Pill",
    [BarMasking.SHAPES.ARROW] = TEXTURE_PATH .. "Mask_Arrow",
    [BarMasking.SHAPES.ANGLE45_UP] = TEXTURE_PATH .. "Mask_Angle45_Up",
    [BarMasking.SHAPES.ANGLE45_DOWN] = TEXTURE_PATH .. "Mask_Angle45_Down",
    [BarMasking.SHAPES.ANGLE22_UP] = TEXTURE_PATH .. "Mask_Angle22_Up",
    [BarMasking.SHAPES.ANGLE22_DOWN] = TEXTURE_PATH .. "Mask_Angle22_Down",
    [BarMasking.SHAPES.CHEVRON] = TEXTURE_PATH .. "Mask_Chevron",
}

-- ============================================================================
-- SHAPE LIST FOR DROPDOWNS
-- ============================================================================

-- Get ordered list of shapes for dropdown menus
function BarMasking:GetShapeList()
    return {
        BarMasking.SHAPES.NONE,
        BarMasking.SHAPES.ROUNDED,
        BarMasking.SHAPES.PILL,
        BarMasking.SHAPES.ARROW,
        BarMasking.SHAPES.ANGLE45_UP,
        BarMasking.SHAPES.ANGLE45_DOWN,
        BarMasking.SHAPES.ANGLE22_UP,
        BarMasking.SHAPES.ANGLE22_DOWN,
        BarMasking.SHAPES.CHEVRON,
    }
end

-- Get display name for a shape
function BarMasking:GetShapeName(shape)
    return BarMasking.SHAPE_NAMES[shape] or shape
end

-- ============================================================================
-- MASK APPLICATION - STATUS BARS
-- ============================================================================

--[[
    Apply a mask shape to a StatusBar frame
    Masks BOTH the status bar texture AND the background
    
    @param statusBar Frame - The StatusBar frame
    @param shape string - One of BarMasking.SHAPES
    @param backgroundTexture Texture - Optional: explicit background texture to mask
]]
function BarMasking:ApplyToStatusBar(statusBar, shape, backgroundTexture)
    if not statusBar then return end
    
    shape = shape or BarMasking.SHAPES.NONE
    
    -- Get the status bar texture
    local barTexture = statusBar:GetStatusBarTexture()
    
    -- Remove existing masks if shape is NONE
    if shape == BarMasking.SHAPES.NONE then
        self:RemoveMasks(statusBar)
        return
    end
    
    local maskPath = MASK_TEXTURES[shape]
    if not maskPath then return end
    
    -- Hide border when masking is applied (rectangular border won't match shaped bar)
    self:HideBorder(statusBar)
    
    -- Create or reuse mask texture for the foreground (status bar fill)
    local fgMask = statusBar._tuiFgMask
    if not fgMask then
        fgMask = statusBar:CreateMaskTexture()
        fgMask:SetAllPoints(statusBar)
        statusBar._tuiFgMask = fgMask
    end
    
    -- Set the mask texture
    fgMask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    
    -- Apply mask to the bar texture (foreground)
    if barTexture then
        -- Remove old mask first to prevent duplicates
        if barTexture.RemoveMaskTexture then
            pcall(function() barTexture:RemoveMaskTexture(fgMask) end)
        end
        barTexture:AddMaskTexture(fgMask)
    end
    
    -- Create or reuse mask texture for the background
    local bgMask = statusBar._tuiBgMask
    if not bgMask then
        bgMask = statusBar:CreateMaskTexture()
        bgMask:SetAllPoints(statusBar)
        statusBar._tuiBgMask = bgMask
    end
    
    -- Set background mask (same shape)
    bgMask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    
    -- Find and mask the background texture
    local bgTexture = backgroundTexture 
        or statusBar.bg 
        or statusBar.Background 
        or statusBar.background
        or statusBar._tuiBackgroundTexture
    
    -- Also check parent frame for background
    if not bgTexture then
        local parent = statusBar:GetParent()
        if parent then
            bgTexture = parent.background or parent.bg or parent.Background
        end
    end
    
    if bgTexture and bgTexture.AddMaskTexture then
        -- Remove old mask first
        if bgTexture.RemoveMaskTexture then
            pcall(function() bgTexture:RemoveMaskTexture(bgMask) end)
        end
        bgTexture:AddMaskTexture(bgMask)
        statusBar._tuiBgTexture = bgTexture
    end
    
    -- Store reference
    statusBar._tuiMaskShape = shape
end

--[[
    Hide the border frame associated with a status bar
]]
function BarMasking:HideBorder(statusBar)
    if not statusBar then return end
    
    -- Look for border in common locations
    local border = statusBar.border 
        or statusBar.borderFrame 
        or statusBar.Border
    
    -- Check parent frame
    if not border then
        local parent = statusBar:GetParent()
        if parent then
            border = parent.border or parent.borderFrame or parent.Border
        end
    end
    
    -- Hide the border and store reference
    if border and border.Hide then
        border:Hide()
        statusBar._tuiHiddenBorder = border
    end
    
    -- Also clear backdrop border if present on parent
    local parent = statusBar:GetParent()
    if parent and parent.SetBackdropBorderColor then
        -- Store original border color
        if not statusBar._tuiOriginalBorderColor then
            local r, g, b, a = 0, 0, 0, 0
            -- Try to get current color (may fail if no backdrop)
            pcall(function()
                r, g, b, a = parent:GetBackdropBorderColor()
            end)
            statusBar._tuiOriginalBorderColor = {r, g, b, a}
        end
        -- Make border invisible
        parent:SetBackdropBorderColor(0, 0, 0, 0)
        statusBar._tuiHiddenBackdropBorder = parent
    end
end

--[[
    Restore the border frame associated with a status bar
]]
function BarMasking:RestoreBorder(statusBar)
    if not statusBar then return end
    
    -- Restore hidden border frame
    if statusBar._tuiHiddenBorder then
        statusBar._tuiHiddenBorder:Show()
        statusBar._tuiHiddenBorder = nil
    end
    
    -- Restore backdrop border color
    if statusBar._tuiHiddenBackdropBorder and statusBar._tuiOriginalBorderColor then
        local c = statusBar._tuiOriginalBorderColor
        statusBar._tuiHiddenBackdropBorder:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
        statusBar._tuiHiddenBackdropBorder = nil
        statusBar._tuiOriginalBorderColor = nil
    end
end

--[[
    Remove all TweaksUI masks from a status bar
]]
function BarMasking:RemoveMasks(statusBar)
    if not statusBar then return end
    
    local barTexture = statusBar:GetStatusBarTexture()
    
    -- Remove foreground mask
    if statusBar._tuiFgMask and barTexture and barTexture.RemoveMaskTexture then
        pcall(function() barTexture:RemoveMaskTexture(statusBar._tuiFgMask) end)
    end
    
    -- Remove background mask
    local bgTexture = statusBar._tuiBgTexture
    if statusBar._tuiBgMask and bgTexture and bgTexture.RemoveMaskTexture then
        pcall(function() bgTexture:RemoveMaskTexture(statusBar._tuiBgMask) end)
    end
    
    -- Restore border visibility
    self:RestoreBorder(statusBar)
    
    -- Clear references
    statusBar._tuiFgMask = nil
    statusBar._tuiBgMask = nil
    statusBar._tuiBgTexture = nil
    statusBar._tuiMaskShape = nil
end

-- ============================================================================
-- MASK APPLICATION - GENERIC FRAME WITH TEXTURES
-- ============================================================================

--[[
    Apply a mask to a frame and all its relevant child textures
    Use this for non-StatusBar frames that have background/fill textures
    
    @param frame Frame - The frame to mask
    @param shape string - One of BarMasking.SHAPES
    @param textures table - Optional list of specific textures to mask
]]
function BarMasking:ApplyToFrame(frame, shape, textures)
    if not frame then return end
    
    shape = shape or BarMasking.SHAPES.NONE
    
    -- Remove existing mask if shape is NONE
    if shape == BarMasking.SHAPES.NONE then
        if frame._tuiFrameMask then
            for texture in pairs(frame._tuiMaskedTextures or {}) do
                if texture and texture.RemoveMaskTexture then
                    pcall(function() texture:RemoveMaskTexture(frame._tuiFrameMask) end)
                end
            end
            frame._tuiFrameMask = nil
            frame._tuiMaskedTextures = nil
        end
        return
    end
    
    local maskPath = MASK_TEXTURES[shape]
    if not maskPath then return end
    
    -- Create shared mask texture
    local maskTexture = frame._tuiFrameMask
    if not maskTexture then
        maskTexture = frame:CreateMaskTexture()
        maskTexture:SetAllPoints(frame)
        frame._tuiFrameMask = maskTexture
        frame._tuiMaskedTextures = {}
    end
    
    -- Set mask
    maskTexture:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    
    -- Collect textures to mask
    local texturesToMask = textures or {}
    
    -- If no explicit list, find common texture names
    if not textures then
        local textureNames = {"Background", "bg", "Bg", "Fill", "fill", "background"}
        for _, name in ipairs(textureNames) do
            local tex = frame[name]
            if tex and tex.AddMaskTexture then
                table.insert(texturesToMask, tex)
            end
        end
        
        -- Also check for StatusBar texture
        if frame.GetStatusBarTexture then
            local barTex = frame:GetStatusBarTexture()
            if barTex then
                table.insert(texturesToMask, barTex)
            end
        end
    end
    
    -- Apply mask to all textures
    for _, tex in ipairs(texturesToMask) do
        if tex and tex.AddMaskTexture then
            pcall(function() tex:RemoveMaskTexture(maskTexture) end)
            tex:AddMaskTexture(maskTexture)
            frame._tuiMaskedTextures[tex] = true
        end
    end
end

-- ============================================================================
-- MASK APPLICATION - SINGLE TEXTURE
-- ============================================================================

--[[
    Apply a mask to a single texture
    
    @param texture Texture - The texture to mask
    @param shape string - One of BarMasking.SHAPES
    @param parentFrame Frame - Parent frame to create mask texture on
]]
function BarMasking:ApplyToTexture(texture, shape, parentFrame)
    if not texture or not parentFrame then return end
    
    shape = shape or BarMasking.SHAPES.NONE
    
    -- Remove existing mask if shape is NONE
    if shape == BarMasking.SHAPES.NONE then
        if texture._tuiMask and texture.RemoveMaskTexture then
            pcall(function() texture:RemoveMaskTexture(texture._tuiMask) end)
            texture._tuiMask = nil
        end
        return
    end
    
    local maskPath = MASK_TEXTURES[shape]
    if not maskPath then return end
    
    -- Create or reuse mask
    local maskTexture = texture._tuiMask
    if not maskTexture then
        maskTexture = parentFrame:CreateMaskTexture()
        maskTexture:SetAllPoints(texture)
        texture._tuiMask = maskTexture
    end
    
    -- Set mask
    maskTexture:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    
    -- Remove old and add new
    pcall(function() texture:RemoveMaskTexture(maskTexture) end)
    texture:AddMaskTexture(maskTexture)
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Get the current mask shape applied to a status bar
function BarMasking:GetStatusBarShape(statusBar)
    if not statusBar then return BarMasking.SHAPES.NONE end
    return statusBar._tuiMaskShape or BarMasking.SHAPES.NONE
end

-- Check if a shape is valid
function BarMasking:IsValidShape(shape)
    return MASK_TEXTURES[shape] ~= nil or shape == BarMasking.SHAPES.NONE
end

-- Get mask texture path for a shape
function BarMasking:GetMaskTexturePath(shape)
    if shape == BarMasking.SHAPES.NONE then return nil end
    return MASK_TEXTURES[shape]
end

-- ============================================================================
-- DEBUG
-- ============================================================================

function BarMasking:DebugListShapes()
    print("|cff00ff00TweaksUI BarMasking:|r Available shapes:")
    for _, shape in ipairs(self:GetShapeList()) do
        local name = self:GetShapeName(shape)
        local path = MASK_TEXTURES[shape] or "(none)"
        print(string.format("  %s: %s", name, path))
    end
end

SLASH_TUIMASKS1 = "/tuimasks"
SlashCmdList["TUIMASKS"] = function()
    BarMasking:DebugListShapes()
end
