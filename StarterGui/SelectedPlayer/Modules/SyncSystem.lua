--[[
	═══════════════════════════════════════════════════════════
	SYNC SYSTEM - Sistema de sincronización
	═══════════════════════════════════════════════════════════
	Maneja la sincronización con otros jugadores
]]

local SyncSystem = {}
local Remotes, State, NotificationSystem, player

function SyncSystem.init(remotes, state)
	Remotes = remotes
	State = state
	NotificationSystem = remotes.Systems.NotificationSystem
	player = remotes.Services.Player

	-- Setup listeners
	SyncSystem.setupListeners()
end

-- ═══════════════════════════════════════════════════════════════
-- FUNCIONES PRINCIPALES
-- ═══════════════════════════════════════════════════════════════

function SyncSystem.syncWithPlayer(targetPlayer)
	if not Remotes.Sync.SyncRemote or not Remotes.Sync.GetSyncState then
		return
	end

	-- Consultar estado actual
	local ok, syncInfo = pcall(function()
		return Remotes.Sync.GetSyncState:InvokeServer()
	end)

	if not ok then
		if NotificationSystem then
			NotificationSystem:Error("Sync", "Error al consultar sincronización", 3)
		end
		return
	end

	-- Si ya estoy sincronizado con ALGUIEN, desincronizar
	if syncInfo and syncInfo.isSynced then
		Remotes.Sync.SyncRemote:FireServer("unsync")
		if NotificationSystem then
			NotificationSystem:Info("Sync", "Has dejado de estar sincronizado", 4)
		end
	else
		-- Validación local: no sincronizarse consigo mismo
		if not targetPlayer or targetPlayer == player then
			if NotificationSystem then
				NotificationSystem:Warning("Sync", "No puedes sincronizarte contigo mismo", 3)
			end
			return
		end

		-- Enviar request al servidor
		Remotes.Sync.SyncRemote:FireServer("sync", targetPlayer)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- LISTENERS
-- ═══════════════════════════════════════════════════════════════

function SyncSystem.setupListeners()
	if Remotes.Sync.SyncUpdate then
		Remotes.Sync.SyncUpdate.OnClientEvent:Connect(function(payload)
			if NotificationSystem and payload and payload.success and payload.isSynced and payload.leaderName then
				NotificationSystem:Success("Sync", "Sincronizado con: " .. payload.leaderName, 4)
			end
		end)
	end
end

return SyncSystem
