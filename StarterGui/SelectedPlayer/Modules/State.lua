--[[
	═══════════════════════════════════════════════════════════
	STATE - Estado compartido del UserPanel
	═══════════════════════════════════════════════════════════
	Estado global compartido entre todos los módulos
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("RemotesGlobal")
local SelectedPlayer = ReplicatedStorage:WaitForChild("SelectedPlayer")

-- Obtener el Highlight existente (no crear uno nuevo como el DISABLE)
local highlight = SelectedPlayer:WaitForChild("Highlight")

return {
	-- UI
	ui = nil,
	container = nil,
	panel = nil,
	statsLabels = {},

	-- Target
	userId = nil,
	target = nil,
	playerColor = nil,

	-- Flags
	closing = false,
	dragging = false,
	isPanelOpening = false,
	isLoadingDynamic = false,

	-- Vistas
	buttonsFrame = nil,
	donationOverlay = nil,

	-- Conexiones
	connections = {},
	refreshThread = nil,

	-- Cache
	avatarCache = {},
	userDataCache = {},

	-- Input
	lastClickTime = 0,

	-- Highlight
	highlight = highlight
}
