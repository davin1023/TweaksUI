-- ============================================================================
-- TweaksUI: Nameplates Module - CVars
-- CVar definitions, application, and restoration
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- CVAR DEFINITIONS
-- ============================================================================

Nameplates.CVarInfo = {
    nameplateShowAll = { default = true, type = "bool", desc = "Show nameplates at all times." },
    nameplateShowFriends = { default = false, type = "bool", desc = "Display nameplates above friendly players." },
    nameplateShowFriendlyNPCs = { default = false, type = "bool", desc = "Always show nameplates for friendly NPCs." },
    nameplateShowEnemies = { default = true, type = "bool", desc = "Display nameplates above enemy players." },
    nameplateShowEnemyMinions = { default = true, type = "bool", desc = "Display nameplates for enemy minions." },
    nameplateShowEnemyGuardians = { default = true, type = "bool", desc = "Display nameplates for enemy guardians." },
    nameplateShowEnemyMinus = { default = true, type = "bool", desc = "Display nameplates for minor enemies." },
    nameplateShowEnemyPets = { default = true, type = "bool", desc = "Display nameplates for enemy pets." },
    nameplateShowEnemyTotems = { default = true, type = "bool", desc = "Display nameplates for enemy totems." },
    nameplateShowDebuffsOnFriendly = { default = true, type = "bool", desc = "Show debuff icons on friendly nameplates." },
    clampTargetNameplateToScreen = { default = true, type = "bool", desc = "Keep target's nameplate visible at screen edge." },
    nameplateMotion = {
        default = 1, type = "dropdown",
        options = { {text = "Overlapping", value = 0}, {text = "Stacking", value = 1} },
        desc = "Overlapping: Nameplates stay above units but may overlap.\nStacking: Nameplates spread out to avoid overlapping."
    },
    nameplateMotionSpeed = { default = 0.025, type = "slider", min = 0.01, max = 0.1, step = 0.005, desc = "How fast nameplates move when stacking." },
    nameplateOverlapH = { default = 0.8, type = "slider", min = 0.0, max = 2.0, step = 0.1, desc = "Horizontal overlap threshold." },
    nameplateOverlapV = { default = 1.1, type = "slider", min = 0.0, max = 2.0, step = 0.1, desc = "Vertical overlap threshold." },
    nameplateMaxDistance = { default = 60, type = "slider", min = 20, max = 60, step = 5, desc = "Maximum distance for nameplates.", format = "%d" },
    nameplateTargetBehindMaxDistance = { default = 40, type = "slider", min = 10, max = 60, step = 5, desc = "Max distance for target behind you.", format = "%d" },
    nameplateGlobalScale = { default = 1.0, type = "slider", min = 0.5, max = 2.0, step = 0.05, desc = "Overall scale multiplier." },
    nameplateMinScale = { default = 0.8, type = "slider", min = 0.5, max = 1.5, step = 0.05, desc = "Scale at far distance." },
    nameplateMaxScale = { default = 1.0, type = "slider", min = 0.5, max = 1.5, step = 0.05, desc = "Scale at close distance." },
    nameplateMinScaleDistance = { default = 10, type = "slider", min = 0, max = 60, step = 5, desc = "Distance for min scale.", format = "%d" },
    nameplateMaxScaleDistance = { default = 10, type = "slider", min = 0, max = 60, step = 5, desc = "Distance for max scale.", format = "%d" },
    nameplateSelectedScale = { default = 1.0, type = "slider", min = 0.5, max = 2.0, step = 0.05, desc = "Scale for current target." },
    nameplateLargerScale = { default = 1.0, type = "slider", min = 0.5, max = 2.0, step = 0.05, desc = "Scale for bosses." },
    NamePlateHorizontalScale = { default = 1.0, type = "slider", min = 0.5, max = 2.0, step = 0.05, desc = "Horizontal stretch factor." },
    NamePlateVerticalScale = { default = 1.0, type = "slider", min = 0.5, max = 2.0, step = 0.05, desc = "Vertical stretch factor." },
    nameplateMinAlpha = { default = 0.6, type = "slider", min = 0.0, max = 1.0, step = 0.05, desc = "Alpha at far distance." },
    nameplateMaxAlpha = { default = 1.0, type = "slider", min = 0.0, max = 1.0, step = 0.05, desc = "Alpha at close distance." },
    nameplateMinAlphaDistance = { default = 10, type = "slider", min = 0, max = 60, step = 5, desc = "Distance for min alpha.", format = "%d" },
    nameplateMaxAlphaDistance = { default = 40, type = "slider", min = 0, max = 60, step = 5, desc = "Distance for max alpha.", format = "%d" },
    nameplateSelectedAlpha = { default = 1.0, type = "slider", min = 0.0, max = 1.0, step = 0.05, desc = "Alpha for current target." },
    nameplateOccludedAlphaMult = { default = 0.4, type = "slider", min = 0.0, max = 1.0, step = 0.05, desc = "Alpha when behind walls." },
}

-- ============================================================================
-- CVAR INITIALIZATION
-- ============================================================================

function Nameplates:InitializeCVarDefaults()
    -- Add CVar defaults to settings if not already present
    if not self.State.settings.cvars then
        self.State.settings.cvars = {}
    end
    
    for cvar, info in pairs(self.CVarInfo) do
        if self.State.settings.cvars[cvar] == nil then
            self.State.settings.cvars[cvar] = info.default
        end
    end
end

-- ============================================================================
-- CVAR APPLICATION
-- ============================================================================

function Nameplates:ApplyCVars()
    local settings = self.State.settings
    if not settings or not settings.cvars then return end
    if self:IsNameplateAddonActive() then return end
    
    for cvar, value in pairs(settings.cvars) do
        if self.State.originalCVars[cvar] == nil then
            self.State.originalCVars[cvar] = GetCVar(cvar)
        end
        if type(value) == "boolean" then
            SetCVar(cvar, value and 1 or 0)
        else
            SetCVar(cvar, value)
        end
    end
end

function Nameplates:RestoreCVars()
    for cvar, value in pairs(self.State.originalCVars) do
        SetCVar(cvar, value)
    end
    self.State.originalCVars = {}
end

-- ============================================================================
-- CVAR GETTER/SETTER
-- ============================================================================

function Nameplates:GetCVarValue(cvar)
    if self.State.settings and self.State.settings.cvars then
        return self.State.settings.cvars[cvar]
    end
    return self.CVarInfo[cvar] and self.CVarInfo[cvar].default
end

function Nameplates:SetCVarValue(cvar, value)
    if not self.State.settings then return end
    if not self.State.settings.cvars then self.State.settings.cvars = {} end
    
    self.State.settings.cvars[cvar] = value
    
    -- Apply the CVar to WoW
    -- Note: Only skip if a DIFFERENT nameplate addon is active (like Plater)
    -- We check if OUR module is handling nameplates - if so, apply CVars
    if type(value) == "boolean" then
        SetCVar(cvar, value and 1 or 0)
    else
        SetCVar(cvar, value)
    end
    
    self:SaveSettings()
end
