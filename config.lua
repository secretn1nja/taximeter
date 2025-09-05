Config = {}

-- Taxi Models
Config.TaxiModel = { 'taxi', 'kuruma', 'adder' }

-- Economy Settings
Config.FareRate = 0.5 -- Rate per meter (1.0 equals distance)
Config.MaxRidesHistory = 10

-- Behavior Settings
Config.PauseOnReset = true

-- Debug Settings
Config.Debug = false -- Set to true for debug messages

-- Key Bindings
Config.Keys = {
    Start = 100,         -- "[" Key - Start meter
    Pause = 197,         -- "]" Key - Pause meter
    Reset = 214,         -- "DELETE" Key - Reset meter
    ToggleDisplay = 323, -- "X" Key - Toggle display
    History = 47         -- "G" Key - View history
}

-- UI Settings
Config.UI = {
    Position = "bottom-right", -- Position of the taximeter UI
    AutoHide = true,          -- Auto-hide when not in taxi
    ShowAnimations = true     -- Enable smooth animations
}

-- Performance Settings
Config.Performance = {
    UpdateInterval = 1000,    -- Meter update interval in ms
    VehicleCheckInterval = 500, -- Vehicle check interval in ms
    RoleUpdateInterval = 1000   -- Role update interval in ms
}

-- Get the exact key codes here: https://docs.fivem.net/docs/game-references/controls/
