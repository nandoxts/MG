--[[
	GlobalModalManager - Sistema centralizado de modales
	Gestiona qué modal está abierto y cierra los otros automáticamente
	Solo UN modal abierto a la vez
	También maneja la deselección de iconos automáticamente
]]

local GlobalModalManager = {}

-- Estado separado: EmoteUI es INDEPENDIENTE, Clan/Music son EXCLUSIVOS
GlobalModalManager.currentMainModal = nil  -- Solo puede ser "Clan" or "Music"
GlobalModalManager.isEmoteOpen = false     -- EmoteUI independiente
GlobalModalManager.isUserPanelOpen = false -- UserPanel independiente
GlobalModalManager.isSettingsOpen = false  -- Settings independiente
GlobalModalManager.settingsModalMgr = nil  -- Instancia del modal de settings

-- Configuración de modales (nombre → funciones open/close)
-- Categorías: "main" (Clan/Music - exclusivos) | "independent" (Emotes - puede coexistir)
local modals = {
	Clan = {
		open = function() 
			if _G.OpenClanUI then 
				local ok, err = pcall(function() _G.OpenClanUI() end)
				if not ok then warn("[GMM] Error abriendo Clan: " .. tostring(err)) end
			else
				warn("[GMM] _G.OpenClanUI no está disponible")
			end
		end,
		close = function() 
			if _G.CloseClanUI then 
				local ok, err = pcall(function() _G.CloseClanUI() end)
				if not ok then warn("[GMM] Error cerrando Clan: " .. tostring(err)) end
			end
		end,
		icon = function() return _G.ClanSystemIcon end,
		category = "main"
	},

	Emotes = {
		open = function() 
			if _G.OpenEmotesUI then 
				local ok, err = pcall(function() _G.OpenEmotesUI() end)
				if not ok then warn("[GMM] Error abriendo Emotes: " .. tostring(err)) end
			else
				warn("[GMM] _G.OpenEmotesUI no está disponible")
			end
		end,
		close = function() 
			if _G.CloseEmotesUI then 
				local ok, err = pcall(function() _G.CloseEmotesUI() end)
				if not ok then warn("[GMM] Error cerrando Emotes: " .. tostring(err)) end
			end
		end,
		icon = function() return nil end,
		category = "independent"
	},

	Music = {
		open = function() 
			if _G.OpenMusicUI then 
				local ok, err = pcall(function() _G.OpenMusicUI() end)
				if not ok then warn("[GMM] Error abriendo Music: " .. tostring(err)) end
			else
				warn("[GMM] _G.OpenMusicUI no está disponible")
			end
		end,
		close = function() 
			if _G.CloseMusicUI then 
				local ok, err = pcall(function() _G.CloseMusicUI() end)
				if not ok then warn("[GMM] Error cerrando Music: " .. tostring(err)) end
			end
		end,
		icon = function() return _G.MusicDashboardIcon end,
		category = "main"
	},

	Shop = {
		open = function() 
			if _G.OpenShopUI then 
				local ok, err = pcall(function() _G.OpenShopUI() end)
				if not ok then warn("[GMM] Error abriendo Shop: " .. tostring(err)) end
			else
				warn("[GMM] _G.OpenShopUI no está disponible")
			end
		end,
		close = function() 
			if _G.CloseShopUI then 
				local ok, err = pcall(function() _G.CloseShopUI() end)
				if not ok then warn("[GMM] Error cerrando Shop: " .. tostring(err)) end
			end
		end,
		icon = function() return _G.ShopIcon end,
		category = "main"
	},

	UserPanel = {
		open = function() end,  -- UserPanel se abre al hacer clic en jugadores
		close = function() 
			if _G.CloseUserPanel then 
				local ok, err = pcall(function() _G.CloseUserPanel() end)
				if not ok then warn("[GMM] Error cerrando UserPanel: " .. tostring(err)) end
			end
		end,
		icon = function() return nil end,  -- No tiene icono en topbar
		category = "independent"  -- Puede coexistir con otros modales
	},

	Menu = {
		open = function()
			if _G.OpenMenuPanel then
				local ok, err = pcall(function() _G.OpenMenuPanel() end)
				if not ok then warn("[GMM] Error abriendo Menu: " .. tostring(err)) end
			else
				warn("[GMM] _G.OpenMenuPanel no está disponible")
			end
		end,
		close = function()
			if _G.CloseMenuPanel then
				local ok, err = pcall(function() _G.CloseMenuPanel() end)
				if not ok then warn("[GMM] Error cerrando Menu: " .. tostring(err)) end
			end
		end,
		icon = function() return _G.MenuIcon end,
		category = "main"  -- Exclusivo: cierra Clan/Music al abrir
	},
}

-- ════════════════════════════════════════════════════════════════
-- FUNCIONES PÚBLICAS
-- ════════════════════════════════════════════════════════════════

function GlobalModalManager:openModal(modalName)
	-- Validar que el modal existe
	if not modals[modalName] then
		warn("[GlobalModalManager] Modal desconocido: " .. modalName)
		return
	end

	local modalConfig = modals[modalName]

	-- MODALES PRINCIPALES (Clan/Music): Solo uno puede estar abierto
	if modalConfig.category == "main" then
		-- Si ya está abierto, no hacer nada
		if self.currentMainModal == modalName then
			return
		end

		-- Cerrar el modal principal anterior si existe
		if self.currentMainModal then
			local prevModal = modals[self.currentMainModal]
			prevModal.close()
			local prevIcon = prevModal.icon()
			if prevIcon then
				pcall(function() prevIcon:deselect() end)
			end
		end

		-- ✅ Cerrar UserPanel si está abierto (modal independiente)
		if self.isUserPanelOpen then
			local userPanelModal = modals["UserPanel"]
			if userPanelModal then
				userPanelModal.close()
				self.isUserPanelOpen = false
			end
		end

		-- Abrir el nuevo modal principal
		self.currentMainModal = modalName
		modalConfig.open()

		-- MODALES INDEPENDIENTES (Emotes): Pueden coexistir con main
	elseif modalConfig.category == "independent" then
		-- Si ya está abierto, no hacer nada
		if self.isEmoteOpen then
			return
		end

		-- Abrir EmoteUI
		self.isEmoteOpen = true
		modalConfig.open()
	end
end

function GlobalModalManager:closeModal(modalName)
	if not modals[modalName] then
		return
	end

	local modalConfig = modals[modalName]

	-- Cerrar modal principal
	if modalConfig.category == "main" then
		if self.currentMainModal == modalName then
			modalConfig.close()
			local icon = modalConfig.icon()
			if icon then
				pcall(function() icon:deselect() end)
			end
			self.currentMainModal = nil
		end

		-- Cerrar modal independiente
	elseif modalConfig.category == "independent" then
		if modalName == "Emotes" and self.isEmoteOpen then
			modalConfig.close()
			local icon = modalConfig.icon()
			if icon then
				pcall(function() icon:deselect() end)
			end
			self.isEmoteOpen = false
		elseif modalName == "UserPanel" and self.isUserPanelOpen then
			modalConfig.close()
			self.isUserPanelOpen = false
		end
	end
end

function GlobalModalManager:getCurrentModal()
	-- Retorna el modal principal actual (para compatibilidad)
	return self.currentMainModal
end

function GlobalModalManager:isModalOpen(modalName)
	if not modals[modalName] then
		return false
	end

	local modalConfig = modals[modalName]
	if modalConfig.category == "main" then
		return self.currentMainModal == modalName
	elseif modalConfig.category == "independent" then
		if modalName == "Emotes" then
			return self.isEmoteOpen
		elseif modalName == "UserPanel" then
			return self.isUserPanelOpen
		end
	end
	return false
end

-- ════════════════════════════════════════════════════════════════
-- SETTINGS MODAL (NUEVO)
-- ════════════════════════════════════════════════════════════════

function GlobalModalManager:ShowSettings(createFn)
	if self.isSettingsOpen then
		return
	end

	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Cerrar modal principal si está abierto
	if self.currentMainModal then
		local prevModal = modals[self.currentMainModal]
		prevModal.close()
		local prevIcon = prevModal.icon()
		if prevIcon then
			pcall(function() prevIcon:deselect() end)
		end
		self.currentMainModal = nil
	end

	-- Crear ScreenGui contenedor
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SettingsScreenGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Crear modal usando la función proporcionada
	self.settingsModalMgr = createFn(screenGui)

	-- Abrir modal (usar open() no Show())
	self.settingsModalMgr:open()
	self.isSettingsOpen = true
end

function GlobalModalManager:CloseSettings()
	if not self.isSettingsOpen or not self.settingsModalMgr then
		return
	end

	self.settingsModalMgr:close()

	local screenGui = self.settingsModalMgr.screenGui
	if screenGui and screenGui.Parent then
		screenGui:Destroy()
	end

	self.settingsModalMgr = nil
	self.isSettingsOpen = false
end

return GlobalModalManager
