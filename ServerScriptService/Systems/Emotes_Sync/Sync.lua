--[[
    Sistema de Sincronización de Emotes
	-- by ignxts
    Arquitectura:
    - Cada jugador puede seguir a UN solo líder (Following)
    - Cada jugador puede tener MÚLTIPLES seguidores (Followers)
    - Cuando un líder cambia de animación, TODOS sus seguidores se actualizan
    - Cuando un líder sigue a otro, sus seguidores heredan la nueva animación
    
    Estructura de datos por jugador:
    {
        Animation = AnimationTrack | nil,      -- Animación actual
        AnimationName = string | nil,          -- Nombre del baile actual
        Following = Player | nil,              -- A quién sigo
        Followers = {Player},                  -- Quiénes me siguen
        Connections = {RBXScriptConnection},   -- Conexiones para cleanup
    }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("RemotesGlobal")
local Animaciones = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Animaciones"))

-- Configuración inline
local Settings = {
	ResetAnimationOnRespawn = true
}

local Remotes = ReplicatedStorage:WaitForChild("Emotes_Sync")

-- Función auxiliar para crear RemoteEvents de forma segura
local function GetOrCreateRemoteEvent(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

-- Función auxiliar para crear RemoteFunctions de forma segura
local function GetOrCreateRemoteFunction(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end

	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

-- RemoteEvent principal para sync/unsync
local SyncRemote = GetOrCreateRemoteEvent(Remotes, "Sync")

-- RemoteEvent para reproducir animaciones
local PlayAnimationRemote = GetOrCreateRemoteEvent(Remotes, "PlayAnimation")

-- RemoteEvent para detener animaciones
local StopAnimationRemote = GetOrCreateRemoteEvent(Remotes, "StopAnimation")

-- RemoteEvent para notificar estado de sincronización a clientes
local SyncUpdate = GetOrCreateRemoteEvent(Remotes, "SyncUpdate")

-- RemoteEvent broadcast para líderes: servidor -> todos los clientes
local SyncBroadcast = GetOrCreateRemoteEvent(Remotes, "SyncBroadcast")

-- RemoteFunction para que el cliente consulte su estado de sincronización
local GetSyncState = GetOrCreateRemoteFunction(Remotes, "GetSyncState")

-- RemoteEvent para Dance Leader UI
local DanceLeaderEvent = GetOrCreateRemoteEvent(Remotes, "DanceLeaderEvent")

-- Configuración
local FADE_TIME = 0.08

-- Estado global de sincronización
local PlayerData = {}

-- Cache de animaciones: nombre -> assetId
local DanceCache = {}

-- Assets para precargar (se construye una vez)
local PreloadAssets = {}

-- Inicializar cache de bailes y emotes (una sola vez)
local function InitializeDanceCache()
	-- Dances (Lista)
	for _, anim in pairs(Animaciones.Lista) do
		local assetId = "rbxassetid://" .. tostring(anim.ID)
		DanceCache[anim.Nombre] = assetId
		local obj = Instance.new("Animation")
		obj.AnimationId = assetId
		table.insert(PreloadAssets, obj)
	end
	-- Emotes / Poses (sin favoritos)
	if Animaciones.Emotes then
		for _, anim in pairs(Animaciones.Emotes) do
			if anim.ID and anim.ID ~= 0 then
				local assetId = "rbxassetid://" .. tostring(anim.ID)
				DanceCache[anim.Nombre] = assetId
				local obj = Instance.new("Animation")
				obj.AnimationId = assetId
				table.insert(PreloadAssets, obj)
			end
		end
	end
end
InitializeDanceCache()

--------------------------------------------------------------------------------

-- Validar que un jugador existe y tiene datos
local function IsValidPlayer(player)
	return player 
		and player.Parent == Players 
		and PlayerData[player] ~= nil
end

-- Implementación de GetSyncState RemoteFunction
GetSyncState.OnServerInvoke = function(player)
	if not IsValidPlayer(player) then
		return { isSynced = false, leaderName = nil }
	end
	local data = PlayerData[player]
	local isSynced = data and data.Following ~= nil
	local leaderName = (data and data.Following) and data.Following.Name or nil
	return { isSynced = isSynced, leaderName = leaderName }
end

-- Validar que un jugador puede bailar (tiene Character, Humanoid, etc.)
local function CanAnimate(player)
	if not IsValidPlayer(player) then return false end

	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then return false end

	local baileAnim = character:FindFirstChild("Baile")
	if not baileAnim then return false end

	return true
end

-- Obtener el líder raíz de una cadena de sincronización
-- Si A sigue a B y B sigue a C, el líder raíz de A es C
local function GetRootLeader(player)
	if not IsValidPlayer(player) then return nil end

	local visited = {}
	local current = player

	while current and PlayerData[current] and PlayerData[current].Following do
		-- Prevenir loops infinitos
		if visited[current] then
			return current
		end
		visited[current] = true
		current = PlayerData[current].Following
	end

	return current
end

-- Obtener TODOS los seguidores de un jugador (recursivamente)
local function GetAllFollowers(player, visited)
	visited = visited or {}
	local allFollowers = {}

	if not IsValidPlayer(player) or visited[player] then 
		return allFollowers 
	end
	visited[player] = true

	local data = PlayerData[player]
	if not data or not data.Followers then return allFollowers end

	for _, follower in ipairs(data.Followers) do
		-- Validar que el seguidor siga siendo válido
		if IsValidPlayer(follower) and not visited[follower] then
			table.insert(allFollowers, follower)
			-- Obtener seguidores de este seguidor también
			local subFollowers = GetAllFollowers(follower, visited)
			for _, subFollower in ipairs(subFollowers) do
				table.insert(allFollowers, subFollower)
			end
		end
	end

	return allFollowers
end

-- Copiar tabla de manera segura (shallow copy)
local function ShallowCopy(tbl)
	local copy = {}
	for i, v in ipairs(tbl) do
		copy[i] = v
	end
	return copy
end

-- Remover un elemento de un array de manera segura
local function SafeRemoveFromArray(array, element)
	for i = #array, 1, -1 do
		if array[i] == element then
			table.remove(array, i)
		end
	end
end

-- Buscar jugador por nombre parcial
local function FindPlayerByName(partialName)
	if not partialName or partialName == "" then return nil end

	partialName = partialName:lower()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name:lower():sub(1, #partialName) == partialName then
			return player
		end
	end
	return nil
end

-- Actualizar atributo de followers en el jugador (para Dance Leader System)
local function UpdateFollowerCount(player)
	if not IsValidPlayer(player) then return end

	local followerCount = #PlayerData[player].Followers
	pcall(function()
		player:SetAttribute("followers", followerCount)
	end)
end

-- Notificar a un jugador sobre quién lo sigue
local function NotifyFollowers(player)
	if not IsValidPlayer(player) then return end

	local followers = PlayerData[player].Followers
	if #followers > 0 then
		local followerNames = {}
		for _, follower in ipairs(followers) do
			if IsValidPlayer(follower) then
				table.insert(followerNames, follower.Name)
			end
		end

		if #followerNames > 0 then
			pcall(function()
				SyncUpdate:FireClient(player, {
					followerNotification = true,
					followerNames = followerNames
				})
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- SISTEMA DE ANIMACIONES
--------------------------------------------------------------------------------

-- Notificar al cliente sobre cambio de animación
local function NotifyClient(player, animationName)
	if not IsValidPlayer(player) then return end

	PlayerData[player].AnimationName = animationName

	pcall(function()
		if animationName then
			PlayAnimationRemote:FireClient(player, "playAnim", animationName)
		else
			StopAnimationRemote:FireClient(player)
		end
	end)

	-- Enviar actualización de sincronización al cliente (payload completo)
	pcall(function()
		local data = PlayerData[player]
		local isSynced = data and data.Following ~= nil
		local leaderName = (data and data.Following) and data.Following.Name or nil
		local leaderUserId = (data and data.Following) and data.Following.UserId or nil

		local speed = nil
		if data and data.Animation and data.Animation.Speed then
			speed = data.Animation.Speed
		end

		-- SIEMPRE enviar payload completo con todos los campos
		SyncUpdate:FireClient(player, { 
			isSynced = isSynced, 
			leaderName = leaderName, 
			leaderUserId = leaderUserId, 
			animationName = animationName, 
			speed = speed 
		})
	end)

	-- Si este player es líder raíz, planificar broadcast debounced a todos los clientes
	pcall(function()
		local rootLeader = GetRootLeader(player)
		if rootLeader == player then
			ScheduleLeaderBroadcast(player)
		end
	end)
end

-- Debounce/batching para broadcasts por líder
local PendingBroadcasts = {}
local BROADCAST_DEBOUNCE = 0.1 -- segundos

local function FireLeaderBroadcast(leader)
	local entry = PendingBroadcasts[leader]
	if not entry then return end
	PendingBroadcasts[leader] = nil

	-- construir payload tomando estado actual del leader
	if not IsValidPlayer(leader) then return end
	local data = PlayerData[leader]
	local payload = {
		leaderUserId = leader.UserId,
		animationName = data and data.AnimationName or nil,
		timePosition = (data and data.Animation) and data.Animation.TimePosition or 0,
		speed = (data and data.Animation) and data.Animation.Speed or 1,
		timestamp = os.time(),
	}

	pcall(function()
		SyncBroadcast:FireAllClients(payload)
	end)
end

function ScheduleLeaderBroadcast(leader)
	if not leader then return end
	-- reemplazar cualquier entrada existente
	if PendingBroadcasts[leader] then
		-- reiniciar timer: (we'll simply ignore because existing task will fire soon)
	else
		PendingBroadcasts[leader] = true
		task.delay(BROADCAST_DEBOUNCE, function()
			FireLeaderBroadcast(leader)
		end)
	end
end

-- Detener la animación de un jugador
local function StopPlayerAnimation(player)
	if not IsValidPlayer(player) then return end

	local data = PlayerData[player]
	if data.Animation then
		pcall(function()
			data.Animation:Stop(FADE_TIME)
			data.Animation:Destroy()
		end)
		data.Animation = nil
	end
	data.AnimationName = nil
end

-- Reproducir una animación en un jugador específico
local function PlayAnimationOnPlayer(player, animationId, animationName, timePosition, speed)
	if not CanAnimate(player) then return false end

	timePosition = timePosition or 0
	speed = speed or 1

	local data = PlayerData[player]
	local character = player.Character
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then return false end

	local baileAnim = character:FindFirstChild("Baile")
	if not baileAnim then return false end

	-- Detener animación actual
	StopPlayerAnimation(player)

	-- Configurar y reproducir nueva animación
	baileAnim.AnimationId = animationId

	local track = animator:LoadAnimation(baileAnim)
	track.Priority = Enum.AnimationPriority.Action
	track:Play(FADE_TIME)
	track.TimePosition = timePosition
	track:AdjustSpeed(speed)

	data.Animation = track
	data.AnimationName = animationName

	return true
end

-- Obtener followers válidos de un jugador (SIN recursión)
local function GetValidFollowers(player)
	if not IsValidPlayer(player) then return {} end

	local validFollowers = {}
	for _, follower in ipairs(PlayerData[player].Followers) do
		if follower and follower.Parent == Players and PlayerData[follower] then
			table.insert(validFollowers, follower)
		end
	end
	return validFollowers
end

-- Agregar seguidor SIN duplicados
local function AddFollower(leader, follower)
	if not IsValidPlayer(leader) or not IsValidPlayer(follower) then return false end

	for _, existing in ipairs(PlayerData[leader].Followers) do
		if existing == follower then
			return false
		end
	end

	table.insert(PlayerData[leader].Followers, follower)
	return true
end

-- Remover seguidor de forma segura
local function RemoveFollower(leader, follower)
	if not IsValidPlayer(leader) then return end
	SafeRemoveFromArray(PlayerData[leader].Followers, follower)
end

-- Propagar animación a seguidores de forma ITERATIVA (sin recursión profunda)
local function PropagateToFollowerChain(followers, animId, animName, timePos, speed)
	local queue = {}
	local processed = {}

	for _, follower in ipairs(followers) do
		if IsValidPlayer(follower) then
			table.insert(queue, follower)
		end
	end

	while #queue > 0 do
		local follower = table.remove(queue, 1)

		if not processed[follower] then
			processed[follower] = true

			if CanAnimate(follower) and follower.Character and follower.Character.Parent then
				PlayAnimationOnPlayer(follower, animId, animName, timePos, speed)
				NotifyClient(follower, animName)

				local subFollowers = GetValidFollowers(follower)
				for _, subFollower in ipairs(subFollowers) do
					if not processed[subFollower] then
						table.insert(queue, subFollower)
					end
				end
			end
		end
	end
end

-- Detener animaciones de todos los seguidores (sin tocar estado de sync)
-- NOTA: Este método ya NO recibe alsoUnsync. Solo detiene animaciones.
-- Para desincronizar al salir un líder, usar OnLeaderRemoving().
local function StopFollowersAnimations(leader)
	if not PlayerData[leader] then return end

	local allFollowers = {}
	local function collectFollowers(currentPlayer, visited)
		visited = visited or {}
		if visited[currentPlayer] then return end
		visited[currentPlayer] = true

		local data = PlayerData[currentPlayer]
		if not data or not data.Followers then return end

		for _, follower in ipairs(data.Followers) do
			if follower and follower.Parent == Players and PlayerData[follower] and not visited[follower] then
				table.insert(allFollowers, follower)
				collectFollowers(follower, visited)
			end
		end
	end
	collectFollowers(leader)

	for _, follower in ipairs(allFollowers) do
		if IsValidPlayer(follower) then
			if CanAnimate(follower) then
				StopPlayerAnimation(follower)
			end
			NotifyClient(follower, nil)
		end
	end
end

--[[
	[FIX] Cuando un líder se sale del juego, solo desincronizar a sus seguidores DIRECTOS.
	Los sub-seguidores mantienen su relación con su sub-líder intacta.
	
	Ejemplo: K,L → A → X ← B ← M,N  y  C → X
	X se sale:
	  - A, B, C: Following = nil (seguían a X directo) → se desincronizan
	  - K, L: siguen synced a A → NO se tocan (A.Followers intacto)
	  - M, N: siguen synced a B → NO se tocan (B.Followers intacto)
	  - Animaciones se detienen para TODOS (el root source ya no existe)
	  
	Después del cleanup:
	  - A es ahora un líder independiente con K,L como seguidores
	  - B es ahora un líder independiente con M,N como seguidores
	  - Cuando A baile algo nuevo, K y L lo seguirán normalmente
]]
local function OnLeaderRemoving(leavingPlayer)
	local data = PlayerData[leavingPlayer]
	if not data then return end

	-- Construir set de seguidores DIRECTOS para lookup rápido
	local directFollowers = data.Followers or {}
	local directSet = {}
	for _, df in ipairs(directFollowers) do
		directSet[df] = true
	end

	-- Recolectar TODOS los seguidores recursivamente (para detener animaciones)
	local allFollowers = {}
	local function collectAll(currentPlayer, visited)
		visited = visited or {}
		if visited[currentPlayer] then return end
		visited[currentPlayer] = true

		local d = PlayerData[currentPlayer]
		if not d or not d.Followers then return end

		for _, follower in ipairs(d.Followers) do
			if follower and follower.Parent == Players and PlayerData[follower] and not visited[follower] then
				table.insert(allFollowers, follower)
				collectAll(follower, visited)
			end
		end
	end
	collectAll(leavingPlayer)

	-- Procesar cada seguidor encontrado
	for _, follower in ipairs(allFollowers) do
		if IsValidPlayer(follower) then
			-- Detener animación de TODOS (el root source se fue)
			if CanAnimate(follower) then
				StopPlayerAnimation(follower)
			end

			if directSet[follower] then
				-- ═══ SEGUIDOR DIRECTO de X ═══
				-- Pierde su Following (ya no sigue a nadie)
				-- PERO conserva sus propios Followers intactos
				PlayerData[follower].Following = nil

				pcall(function()
					follower:SetAttribute("following", nil)
				end)

				-- Notificar: ya no está synced, sin animación
				pcall(function()
					SyncUpdate:FireClient(follower, { 
						isSynced = false, 
						leaderName = nil, 
						animationName = nil, 
						speed = nil 
					})
					StopAnimationRemote:FireClient(follower)
				end)
			else
				-- ═══ SUB-SEGUIDOR (no seguía a X directamente) ═══
				-- Mantiene su Following y su posición en la cadena intacta
				-- Solo pierde la animación porque el root ya no existe
				local fData = PlayerData[follower]
				local leaderRef = fData.Following
				local leaderName = (leaderRef and IsValidPlayer(leaderRef)) and leaderRef.Name or nil
				local leaderUserId = (leaderRef and IsValidPlayer(leaderRef)) and leaderRef.UserId or nil

				pcall(function()
					SyncUpdate:FireClient(follower, { 
						isSynced = (leaderRef ~= nil), 
						leaderName = leaderName,
						leaderUserId = leaderUserId,
						animationName = nil,
						speed = nil 
					})
					StopAnimationRemote:FireClient(follower)
				end)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- SISTEMA DE SINCRONIZACIÓN
--------------------------------------------------------------------------------

-- Dejar de seguir a un líder
local function Unfollow(player)
	if not IsValidPlayer(player) then return end

	local data = PlayerData[player]
	local currentLeader = data.Following

	if currentLeader and IsValidPlayer(currentLeader) then
		RemoveFollower(currentLeader, player)
		UpdateFollowerCount(currentLeader)
	end

	data.Following = nil

	pcall(function()
		player:SetAttribute("following", nil)
	end)

	pcall(function()
		SyncUpdate:FireClient(player, { isSynced = false, leaderName = nil, animationName = nil, speed = nil })
	end)
end

-- Seguir a un nuevo líder
local function Follow(follower, leader)
	if not IsValidPlayer(follower) or not IsValidPlayer(leader) then return false end
	if follower == leader then return false end

	-- Prevenir loops: no puedo seguir a alguien que me sigue (directa o indirectamente)
	local allMyFollowers = GetAllFollowers(follower)
	for _, f in ipairs(allMyFollowers) do
		if f == leader then
			return false
		end
	end

	-- Guardar mis seguidores válidos antes de cambiar
	local myFollowers = GetValidFollowers(follower)

	-- Dejar de seguir al líder anterior si existe (SILENCIOSAMENTE)
	local followerData = PlayerData[follower]
	local currentLeader = followerData.Following
	if currentLeader and IsValidPlayer(currentLeader) then
		RemoveFollower(currentLeader, follower)
		UpdateFollowerCount(currentLeader)
	end

	-- Validar nuevamente que el líder sigue siendo válido
	if not IsValidPlayer(leader) then return false end

	-- Establecer nuevo líder
	followerData.Following = leader

	pcall(function()
		follower:SetAttribute("following", leader.Name)
	end)

	AddFollower(leader, follower)
	UpdateFollowerCount(leader)

	-- Restaurar mis seguidores (ellos me siguen a mí, no al nuevo líder)
	followerData.Followers = myFollowers

	-- Obtener la animación del líder raíz
	local rootLeader = GetRootLeader(leader)
	local animName = nil
	local speed = nil
	local hasAnimation = false

	if rootLeader and IsValidPlayer(rootLeader) then
		local rootData = PlayerData[rootLeader]
		if rootData.Animation then
			local animId = rootData.Animation.Animation.AnimationId
			animName = rootData.AnimationName
			local timePos = rootData.Animation.TimePosition
			speed = rootData.Animation.Speed
			hasAnimation = true

			PlayAnimationOnPlayer(follower, animId, animName, timePos, speed)

			if #myFollowers > 0 then
				PropagateToFollowerChain(myFollowers, animId, animName, timePos, speed)
			end
		end
	end

	local leaderUserId = rootLeader and rootLeader.UserId or leader.UserId

	pcall(function()
		SyncUpdate:FireClient(follower, { 
			isSynced = true, 
			leaderName = leader.Name, 
			leaderUserId = leaderUserId, 
			animationName = animName, 
			speed = speed,
			success = true
		})
	end)

	if hasAnimation and animName then
		pcall(function()
			PlayAnimationRemote:FireClient(follower, "playAnim", animName)
		end)
	end

	return true
end

--------------------------------------------------------------------------------
-- HANDLERS DE EVENTOS
--------------------------------------------------------------------------------

-- Reproducir animación (desde cliente)
local function OnPlayAnimation(player, action, animationData, speedParam)
	if not IsValidPlayer(player) then return end

	if action == "playAnim" and animationData and DanceCache[animationData] then
		local speed = (type(speedParam) == "number") and math.clamp(speedParam, 0.1, 5.0) or 1
		local myFollowers = GetValidFollowers(player)

		Unfollow(player)

		PlayerData[player].Followers = myFollowers

		local animId = DanceCache[animationData]
		if PlayAnimationOnPlayer(player, animId, animationData, 0, speed) then
			NotifyClient(player, animationData)

			if IsValidPlayer(player) and #myFollowers > 0 then
				PropagateToFollowerChain(myFollowers, animId, animationData, 0, speed)
			end
		end

	elseif action == "setSpeed" and type(animationData) == "number" then
		local speed = math.clamp(animationData, 0.1, 5.0)
		local data = PlayerData[player]
		if data and data.Animation then
			pcall(function() data.Animation:AdjustSpeed(speed) end)
			-- Propagar velocidad a todos los seguidores en la cadena
			local allFollowers = GetAllFollowers(player)
			for _, follower in ipairs(allFollowers) do
				if IsValidPlayer(follower) then
					local fData = PlayerData[follower]
					if fData and fData.Animation then
						pcall(function() fData.Animation:AdjustSpeed(speed) end)
					end
				end
			end
			-- Notificar a clientes (incluye speed en el payload via NotifyClient)
			NotifyClient(player, data.AnimationName)
		end
	end
end

-- Detener animación (desde cliente)
local function OnStopAnimation(player)
	if not IsValidPlayer(player) then return end

	StopPlayerAnimation(player)
	NotifyClient(player, nil)

	StopFollowersAnimations(player)
end

-- Acción de sincronización (desde cliente)
local function OnSyncAction(player, action, target)
	if not IsValidPlayer(player) then return end

	if action == "sync" then
		local targetPlayer
		if typeof(target) == "Instance" and target:IsA("Player") then
			targetPlayer = target
		elseif typeof(target) == "string" then
			targetPlayer = FindPlayerByName(target)
		end

		if not targetPlayer or not IsValidPlayer(targetPlayer) then
			pcall(function()
				SyncUpdate:FireClient(player, { 
					isSynced = false, 
					leaderName = nil, 
					animationName = nil, 
					speed = nil,
					syncError = "Jugador no encontrado"
				})
			end)
			return
		end

		if player == targetPlayer then
			pcall(function()
				SyncUpdate:FireClient(player, { 
					isSynced = false, 
					leaderName = nil, 
					animationName = nil, 
					speed = nil,
					syncError = "No puedes sincronizarte contigo mismo"
				})
			end)
			return
		end

		local allMyFollowers = GetAllFollowers(player)
		for _, f in ipairs(allMyFollowers) do
			if f == targetPlayer then
				pcall(function()
					SyncUpdate:FireClient(player, { 
						isSynced = false, 
						leaderName = nil, 
						animationName = nil, 
						speed = nil,
						syncError = "No puedes sincronizarte con " .. targetPlayer.Name .. " (ya te sigue)"
					})
				end)
				return
			end
		end

		local syncSuccess = Follow(player, targetPlayer)

		if syncSuccess then
			NotifyFollowers(targetPlayer)
		else
			pcall(function()
				SyncUpdate:FireClient(player, { 
					isSynced = false, 
					leaderName = nil, 
					animationName = nil, 
					speed = nil,
					syncError = "Error al sincronizar con " .. targetPlayer.Name
				})
			end)
		end

	elseif action == "unsync" then
		local myFollowers = GetValidFollowers(player)

		Unfollow(player)

		StopPlayerAnimation(player)
		NotifyClient(player, nil)

		PlayerData[player].Followers = myFollowers
		StopFollowersAnimations(player)
	end
end

--------------------------------------------------------------------------------
-- MANEJO DE JUGADORES
--------------------------------------------------------------------------------

local function OnCharacterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player or not PlayerData[player] then return end

	local wasFollowing = PlayerData[player].Following
	local myFollowers = GetValidFollowers(player)

	for otherPlayer, data in pairs(PlayerData) do
		if otherPlayer ~= player and IsValidPlayer(otherPlayer) then
			RemoveFollower(otherPlayer, player)
		end
	end

	local animation = Instance.new("Animation")
	animation.Name = "Baile"
	animation.Parent = character

	task.spawn(function()
		local humanoid = character:FindFirstChild("Humanoid")

		if not humanoid then
			humanoid = character:WaitForChild("Humanoid", 1)
		end

		if humanoid then
			local diedConnection
			diedConnection = humanoid.Died:Connect(function()
				if diedConnection then
					diedConnection:Disconnect()
					diedConnection = nil
				end

				if not IsValidPlayer(player) then return end
				if not PlayerData[player] then return end

				StopPlayerAnimation(player)

				local myFollowers = ShallowCopy(PlayerData[player].Followers)

				if PlayerData[player].Following then
					Unfollow(player)
				end

				for otherPlayer, data in pairs(PlayerData) do
					if otherPlayer ~= player and IsValidPlayer(otherPlayer) then
						RemoveFollower(otherPlayer, player)
					end
				end

				if Settings.ResetAnimationOnRespawn then
					StopFollowersAnimations(player)
					PlayerData[player].Followers = {}
				end
			end)

			if PlayerData[player] then
				table.insert(PlayerData[player].Connections, diedConnection)
			end
		end

		task.wait(0.5)

		if not IsValidPlayer(player) then return end

		PlayerData[player].Followers = myFollowers
		UpdateFollowerCount(player)

		if wasFollowing and IsValidPlayer(wasFollowing) then
			Follow(player, wasFollowing)
		end

		if #myFollowers > 0 then
			NotifyFollowers(player)
		end
	end)
end

local function OnPlayerAdded(player)
	PlayerData[player] = {
		Animation = nil,
		AnimationName = nil,
		Following = nil,
		Followers = {},
		Connections = {},
	}

	local charConnection = player.CharacterAdded:Connect(OnCharacterAdded)
	table.insert(PlayerData[player].Connections, charConnection)

	if player.Character then
		OnCharacterAdded(player.Character)
	end

	local chatConnection = player.Chatted:Connect(function(message)
		local args = message:split(" ")
		local command = args[1] and args[1]:lower()

		if command == "sync" and args[2] then
			local targetPlayer = FindPlayerByName(args[2])
			if targetPlayer and player ~= targetPlayer then
				Follow(player, targetPlayer)
			end
		elseif command == "unsync" then
			OnSyncAction(player, "unsync", nil)
		end
	end)
	table.insert(PlayerData[player].Connections, chatConnection)
end

--[[
	[FIX] OnPlayerRemoving reescrito completamente.
	
	Problema original: 
	  1. Unfollow() fallaba porque IsValidPlayer chequea player.Parent == Players
	     y al dispararse PlayerRemoving el jugador ya está saliendo.
	  2. StopFollowersAnimations(player, true) destruía TODA la cadena de sync,
	     incluyendo sub-seguidores que no seguían al jugador directamente.
	
	Fix:
	  - Usar OnLeaderRemoving() que solo desincroniza DIRECTOS y preserva sub-cadenas
	  - Limpiar relación con líder manualmente (sin Unfollow)
	  - Limpiar referencias stale en todos los demás jugadores
]]
local function OnPlayerRemoving(player)
	if not PlayerData[player] then return end

	local data = PlayerData[player]

	-- 1. [FIX] Desincronizar solo seguidores DIRECTOS, preservar sub-cadenas
	--    K,L→A→X: solo A pierde sync, K y L siguen a A normalmente
	OnLeaderRemoving(player)

	-- 2. Detener mi animación (sin usar IsValidPlayer que falla aquí)
	if data.Animation then
		pcall(function()
			data.Animation:Stop(FADE_TIME)
			data.Animation:Destroy()
		end)
		data.Animation = nil
	end
	data.AnimationName = nil

	-- 3. [FIX] Limpiar mi relación con mi líder MANUALMENTE
	--    (no usar Unfollow() porque IsValidPlayer(player) falla aquí)
	local myLeader = data.Following
	if myLeader and PlayerData[myLeader] then
		SafeRemoveFromArray(PlayerData[myLeader].Followers, player)

		if myLeader.Parent == Players then
			UpdateFollowerCount(myLeader)
			NotifyFollowers(myLeader)
		end
	end
	data.Following = nil

	-- 4. [FIX] Remover de la lista de seguidores de TODOS los demás jugadores
	--    + actualizar sus follower counts
	for otherPlayer, otherData in pairs(PlayerData) do
		if otherPlayer ~= player and otherPlayer.Parent == Players then
			local hadFollower = false
			for i = #otherData.Followers, 1, -1 do
				if otherData.Followers[i] == player then
					table.remove(otherData.Followers, i)
					hadFollower = true
				end
			end
			if hadFollower then
				UpdateFollowerCount(otherPlayer)
			end
		end
	end

	-- 5. Limpiar broadcasts pendientes
	PendingBroadcasts[player] = nil

	-- 6. Desconectar todas las conexiones
	for _, connection in ipairs(data.Connections) do
		if connection then
			pcall(function() connection:Disconnect() end)
		end
	end

	-- 7. Limpiar datos
	PlayerData[player] = nil
end

--------------------------------------------------------------------------------
-- INICIALIZACIÓN
--------------------------------------------------------------------------------

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)
PlayAnimationRemote.OnServerEvent:Connect(OnPlayAnimation)
StopAnimationRemote.OnServerEvent:Connect(OnStopAnimation)
SyncRemote.OnServerEvent:Connect(OnSyncAction)

for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end