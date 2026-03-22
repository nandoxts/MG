--[[
	═══════════════════════════════════════════════════════════
	USER PANEL CLIENT - v4.0 (Server-Cached)
	═══════════════════════════════════════════════════════════
	• Client SLIM: solo open/close/input
	• Toda la caché y pre-carga vive en el SERVER
	• InvokeServer responde instantáneo (~0ms desde caché)
	• Group icon cacheado permanente en server (1 fetch por sesión)
	• Vista delegada a PanelView module
]]

-- ═══════════════════════════════════════════════════════════════
-- MÓDULOS
-- ═══════════════════════════════════════════════════════════════
local Modules = script.Parent.Modules

local Config = require(Modules.Config)
local State = require(Modules.State)
local RemotesSetup = require(Modules.RemotesSetup)
local Utils = require(Modules.Utils)
local SyncSystem = require(Modules.SyncSystem)
local LikesSystem = require(Modules.LikesSystem)
local InputHandler = require(Modules.InputHandler)
local PanelView = require(Modules.PanelView)

-- ═══════════════════════════════════════════════════════════════
-- INICIALIZACIÓN
-- ═══════════════════════════════════════════════════════════════
local Remotes = RemotesSetup()
local Services = Remotes.Services
local player = Services.Player
local ColorEffects = Remotes.Systems.ColorEffects

Utils.init(Config, State)
SyncSystem.init(Remotes, State)
LikesSystem.init(Remotes, State, Config)
PanelView.init(Config, State, Utils, Remotes)

-- ═══════════════════════════════════════════════════════════════
-- CERRAR PANEL
-- ═══════════════════════════════════════════════════════════════
local function closePanel()
	if State.closing or not State.ui then return end
	State.closing = true

	if State.refreshThread then task.cancel(State.refreshThread) end

	pcall(function()
		if Remotes.Systems.GlobalModalManager then
			Remotes.Systems.GlobalModalManager.isUserPanelOpen = false
		end
	end)

	-- Capturar referencias locales para la animación
	local closingUi = State.ui
	local closingContainer = State.container
	local L = PanelView.getLayout()

	-- INMEDIATAMENTE desactivar interactividad del panel que se cierra
	-- Esto evita que gameProcessed=true bloquee el siguiente clic del usuario
	pcall(function()
		for _, desc in ipairs(closingUi:GetDescendants()) do
			if desc:IsA("GuiButton") or desc:IsA("ScrollingFrame") then
				desc.Active = false
			end
		end
	end)

	-- Quitar highlight
	Utils.setHighlightTarget(nil, State, ColorEffects)

	-- Limpiar conexiones y tweens
	PanelView.cleanupTweens()
	Utils.clearConnections()

	-- RESETEAR TODO EL STATE INMEDIATAMENTE (no esperar animación)
	State.ui = nil
	State.userId = nil
	State.target = nil
	State.container = nil
	State.panel = nil
	State.buttonsFrame = nil
	State.buttonsOverlay = nil
	State.donationOverlay = nil
	State.statsLabels = {}
	State.isLoadingDynamic = false
	State.dragging = false
	State.closing = false
	State.isPanelOpening = false
	State.playerColor = nil
	State.panelBgImage = nil
	State.panelStroke = nil
	State.panelContainer = nil

	-- Animar cierre visualmente (sobre las referencias capturadas)
	if closingContainer and closingContainer.Parent then
		PanelView.safeTween(closingContainer, {
			Position = UDim2.new(0.5, -L.panelWidth / 2, 1, 50)
		}, 1, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	end

	-- Destruir después de que termine la animación
	task.delay(1.05, function()
		pcall(function() closingUi:Destroy() end)
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- ABRIR PANEL
-- ═══════════════════════════════════════════════════════════════
-- El server tiene background pre-cache → InvokeServer responde
-- instantáneo desde caché (~0ms). Si por alguna razón no hay
-- caché aún, el server fetchea con paralelo (~250ms).
-- ═══════════════════════════════════════════════════════════════
local function openPanel(target)
	if State.isPanelOpening or not target then return end
	State.isPanelOpening = true

	if State.refreshThread then task.cancel(State.refreshThread) end

	-- Cleanup previo
	Utils.clearConnections()
	PanelView.cleanupTweens()

	if State.ui then State.ui:Destroy(); State.ui = nil end

	State.userId = target.UserId
	State.target = target

	-- Datos básicos (instantáneos, no requieren server)
	local initialData = {
		userId      = target.UserId,
		username    = target.Name,
		displayName = target.DisplayName,
		isPremium   = (target.MembershipType == Enum.MembershipType.Premium),
		avatar      = Utils.getAvatarImage(target.UserId),
		followers   = 0,
		friends     = 0,
		likes       = 0,
	}

	-- PASO 1: MOSTRAR HIGHLIGHT PRIMERO
	Utils.setHighlightTarget(target, State, ColorEffects)

	-- PASO 2: CREAR PANEL con datos básicos (aparece rápido)
	local success, result = pcall(PanelView.createPanel, initialData)

	if success and result then
		State.ui = result
		State.target = target

		pcall(function()
			local gmm = Remotes.Systems.GlobalModalManager
			if gmm then
				if gmm.isEmoteOpen == nil then gmm.isEmoteOpen = false end
				gmm.isUserPanelOpen = true
			end
		end)

		-- PASO 3: Pedir data real al server (responde del caché → instantáneo)
		task.spawn(function()
			local ok, data = pcall(function()
				return Remotes.Remotes.GetUserData:InvokeServer(target.UserId)
			end)
			if ok and data and State.ui and State.userId == target.UserId then
				-- Actualizar stats en vivo
				Utils.updateStats(data, true, State)
				-- Aplicar fondo VIP si corresponde
				if data.isVip and data.groupIcon then
					PanelView.applyVipBackground(data.groupIcon, State.playerColor)
				end
			end
		end)

		State.isPanelOpening = false
	else
		State.isPanelOpening = false
		warn("[UserPanel] Error creando panel:", result)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- INPUT & CURSOR
-- ═══════════════════════════════════════════════════════════════
InputHandler.setupListeners(openPanel, closePanel, State)
InputHandler.setupCursor(State, Services)

-- ═══════════════════════════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════════════════════════
_G.CloseUserPanel = closePanel

return {
	open = openPanel,
	close = closePanel,
}