-- TweaksUI Module Manager
-- Handles loading, enabling, and disabling of modules

local ADDON_NAME, TweaksUI = ...

TweaksUI.ModuleManager = {}
local MM = TweaksUI.ModuleManager

-- Registered modules
local modules = {}

-- Module base template
local ModulePrototype = {
    -- Module metadata
    id = nil,
    name = nil,
    description = nil,
    version = "1.0.0",
    
    -- State
    loaded = false,
    enabled = false,
    
    -- Lifecycle methods (override in modules)
    OnInitialize = function(self) end,  -- Called once when module first loads
    OnEnable = function(self) end,      -- Called when module is enabled
    OnDisable = function(self) end,     -- Called when module is disabled
    OnProfileChanged = function(self, profileName) end, -- Called when profile changes
    
    -- Settings access helpers
    GetSettings = function(self)
        return TweaksUI.Database:GetModuleSettings(self.id)
    end,
    
    GetSetting = function(self, key)
        local settings = self:GetSettings()
        return settings[key]
    end,
    
    SetSetting = function(self, key, value)
        TweaksUI.Database:SetModuleSetting(self.id, key, value)
    end,
}

-- Create a new module
function MM:NewModule(id, name, description)
    if modules[id] then
        TweaksUI:PrintError("Module '" .. id .. "' already exists!")
        return nil
    end
    
    local module = setmetatable({}, { __index = ModulePrototype })
    module.id = id
    module.name = name or TweaksUI.MODULE_NAMES[id] or id
    module.description = description or ""
    
    modules[id] = module
    
    return module
end

-- Get a module by ID
function MM:GetModule(id)
    return modules[id]
end

-- Get all modules
function MM:GetAllModules()
    return modules
end

-- Initialize all modules
function MM:InitializeAll()
    -- Initialize in defined order
    for _, moduleId in ipairs(TweaksUI.MODULE_LOAD_ORDER) do
        local module = modules[moduleId]
        if module and not module.loaded then
            local success, err = pcall(function()
                module:OnInitialize()
                module.loaded = true
            end)
            
            if not success then
                TweaksUI:PrintError("Failed to initialize module '" .. moduleId .. "': " .. tostring(err))
            end
        end
    end
    
    -- Initialize any modules not in the load order
    for moduleId, module in pairs(modules) do
        if not module.loaded then
            local success, err = pcall(function()
                module:OnInitialize()
                module.loaded = true
            end)
            
            if not success then
                TweaksUI:PrintError("Failed to initialize module '" .. moduleId .. "': " .. tostring(err))
            end
        end
    end
end

-- Enable all modules that should be enabled
function MM:EnableAll()
    for _, moduleId in ipairs(TweaksUI.MODULE_LOAD_ORDER) do
        local module = modules[moduleId]
        if module and module.loaded and TweaksUI.Database:IsModuleEnabled(moduleId) then
            self:EnableModule(moduleId)
        end
    end
    
    -- Enable any modules not in the load order
    for moduleId, module in pairs(modules) do
        if module.loaded and not module.enabled and TweaksUI.Database:IsModuleEnabled(moduleId) then
            self:EnableModule(moduleId)
        end
    end
end

-- Enable a specific module
function MM:EnableModule(moduleId)
    local module = modules[moduleId]
    if not module then
        TweaksUI:PrintError("Module '" .. moduleId .. "' not found")
        return false
    end
    
    if not module.loaded then
        TweaksUI:PrintError("Module '" .. moduleId .. "' not initialized")
        return false
    end
    
    if module.enabled then
        return true -- Already enabled
    end
    
    local success, err = pcall(function()
        module:OnEnable()
        module.enabled = true
    end)
    
    if not success then
        TweaksUI:PrintError("Failed to enable module '" .. moduleId .. "': " .. tostring(err))
        return false
    end
    
    TweaksUI.Database:SetModuleEnabled(moduleId, true)
    TweaksUI:PrintDebug("Module '" .. module.name .. "' enabled")
    
    return true
end

-- Disable a specific module
function MM:DisableModule(moduleId)
    local module = modules[moduleId]
    if not module then
        TweaksUI:PrintError("Module '" .. moduleId .. "' not found")
        return false
    end
    
    if not module.enabled then
        return true -- Already disabled
    end
    
    local success, err = pcall(function()
        module:OnDisable()
        module.enabled = false
    end)
    
    if not success then
        TweaksUI:PrintError("Failed to disable module '" .. moduleId .. "': " .. tostring(err))
        return false
    end
    
    TweaksUI.Database:SetModuleEnabled(moduleId, false)
    TweaksUI:Print("Module '" .. module.name .. "' disabled")
    
    return true
end

-- Toggle a module
function MM:ToggleModule(moduleId)
    local module = modules[moduleId]
    if not module then
        return false
    end
    
    if module.enabled then
        return self:DisableModule(moduleId)
    else
        return self:EnableModule(moduleId)
    end
end

-- Check if a module is enabled
function MM:IsModuleEnabled(moduleId)
    local module = modules[moduleId]
    return module and module.enabled
end

-- Notify modules of profile change
function MM:NotifyProfileChanged(profileName)
    for _, module in pairs(modules) do
        if module.enabled then
            local success, err = pcall(function()
                module:OnProfileChanged(profileName)
            end)
            
            if not success then
                TweaksUI:PrintError("Profile change error in module '" .. module.id .. "': " .. tostring(err))
            end
        end
    end
end

-- Register for profile change events
TweaksUI.Events:Register(TweaksUI.EVENTS.PROFILE_CHANGED, function(profileName)
    MM:NotifyProfileChanged(profileName)
end)
