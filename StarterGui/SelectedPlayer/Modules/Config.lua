--[[
	═══════════════════════════════════════════════════════════
	CONFIG - Configuraciones del UserPanel
	═══════════════════════════════════════════════════════════
	Todas las constantes y configuraciones estáticas
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local configFolder = ReplicatedStorage:FindFirstChild("Config") or ReplicatedStorage:WaitForChild("Config", 2)
local THEME = pcall(function()
	return require(configFolder:FindFirstChild("ThemeConfig") or configFolder:WaitForChild("ThemeConfig", 2))
end) and require(configFolder:FindFirstChild("ThemeConfig") or configFolder:WaitForChild("ThemeConfig", 2)) or {}
local GLOBAL_CFG = pcall(function()
	return require(configFolder:FindFirstChild("Configuration") or configFolder:WaitForChild("Configuration", 2))
end) and require(configFolder:FindFirstChild("Configuration") or configFolder:WaitForChild("Configuration", 2)) or {}

local UserInputService = game:GetService("UserInputService")

-- Detectar si es mobile (función dinámica)
local function isMobileDevice()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Función para obtener dimensiones dinámicamente (como ModalManager)
local function getDimensions()
	local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	return {
		PANEL_WIDTH = isMobile and 210 or 250,
		PANEL_HEIGHT = isMobile and 210 or 250,
		AVATAR_HEIGHT = isMobile and 210 or 250,
		BUTTON_HEIGHT = isMobile and 38 or 38,
		CARD_SIZE = isMobile and 75 or 75,
		STATS_WIDTH = isMobile and 70 or 70,
		STATS_ITEM_HEIGHT = isMobile and 50 or 50,
	}
end

-- Valores iniciales (actualizar dinámicamente)
local dims = getDimensions()

return {
	-- Device detection y dimensiones dinámicas
	isMobileDevice = isMobileDevice,
	getDimensions = getDimensions,

	-- Dimensiones del panel (iniciales)
	PANEL_WIDTH = dims.PANEL_WIDTH,
	PANEL_HEIGHT = dims.PANEL_HEIGHT,
	PANEL_PADDING = 12,

	-- Avatar
	AVATAR_HEIGHT = dims.AVATAR_HEIGHT,
	AVATAR_ZOOM = isMobileDevice() and 1.1 or 1.2,

	-- Stats
	STATS_WIDTH = dims.STATS_WIDTH,
	STATS_ITEM_HEIGHT = dims.STATS_ITEM_HEIGHT,

	-- Botones
	BUTTON_HEIGHT = dims.BUTTON_HEIGHT,
	BUTTON_GAP = isMobileDevice() and 6 or 8,
	BUTTON_CORNER = 10,

	-- Cards
	CARD_SIZE = dims.CARD_SIZE,

	-- Animaciones
	ANIM_FAST = 0.12,
	ANIM_NORMAL = 0.2,

	-- Cache y refresh
	AVATAR_CACHE_TIME = 300,
	AUTO_REFRESH_INTERVAL = 60,

	-- Raycast y input
	MAX_RAYCAST_DISTANCE = 80,
	CLICK_DEBOUNCE = isMobileDevice() and 0.5 or 0.3,

	-- Touch
	TOUCH_ENABLED = true,
	LONG_PRESS_TIME = 0.5,

	-- Cursores (solo desktop)
	DEFAULT_CURSOR = "rbxassetid://13335399499",
	SELECTED_CURSOR = "rbxassetid://84923889690331",

	-- Tema
	THEME = THEME,

	-- UI icons
	PREMIUM_ICON = (GLOBAL_CFG.UIIcons and GLOBAL_CFG.UIIcons.Premium) or "rbxassetid://13600832988"
}
