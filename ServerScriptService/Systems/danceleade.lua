--[[
    Dance Leader System - SERVER
    by ignxts
    25/01/2026
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("RemotesGlobal")
local Emotes_Sync = ReplicatedStorage:WaitForChild("Emotes_Sync")
local Configuration = require(game.ReplicatedStorage.Config.Configuration)

-- Configuración
local FOLLOWER_DANCE_THRESHOLD = Configuration.FOLLOWER_DANCE or 2
local CHECK_INTERVAL = Configuration.CHECK_TIME_FOLLOWER or 300
local BILLBOARD_NAME = Configuration.BILLBOARD_NAME or "Dance_Leader"

-- Obtener RemoteEvent existente
local DanceLeaderEvent = Emotes_Sync:WaitForChild("DanceLeaderEvent")

-- Estado de líderes actuales
local CurrentDanceLeaders = {}

-- Función para obtener a quién sigue un jugador (desde atributo "following")
local function GetFollowing(player)
	if not player or player.Parent ~= Players then return nil end
	local followingName = player:GetAttribute("following")
	if followingName then
		return Players:FindFirstChild(followingName)
	end
	return nil
end

-- Función para obtener el LÍDER RAÍZ de una cadena
-- Si A sigue a B y B sigue a C, el líder raíz de A es C
local function GetRootLeader(player)
	if not player or player.Parent ~= Players then return nil end

	local visited = {}
	local current = player

	while current and current.Parent == Players do
		-- Prevenir loops
		if visited[current] then
			return current
		end
		visited[current] = true

		local following = GetFollowing(current)
		if not following then
			-- Este jugador no sigue a nadie, es el líder raíz
			return current
		end
		current = following
	end

	return player -- Si algo falla, retornar el jugador original
end

-- Obtener TODOS los jugadores que siguen a un líder (directa o indirectamente)
local function GetAllFollowersRecursive(leader, visited)
	visited = visited or {}
	local allFollowers = {}

	if not leader or visited[leader] then 
		return allFollowers 
	end
	visited[leader] = true

	-- Buscar todos los jugadores que siguen directamente a este líder
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= leader and player.Parent == Players and not visited[player] then
			local following = GetFollowing(player)
			if following == leader then
				table.insert(allFollowers, player)
				-- Recursivamente obtener los que siguen a este jugador
				local subFollowers = GetAllFollowersRecursive(player, visited)
				for _, subFollower in ipairs(subFollowers) do
					table.insert(allFollowers, subFollower)
				end
			end
		end
	end

	return allFollowers
end

-- Contar SOLO los seguidores (sin incluir al líder)
local function GetFollowerCount(rootLeader)
	if not rootLeader or rootLeader.Parent ~= Players then return 0 end

	-- Contar solo los seguidores (sin el líder)
	local allFollowers = GetAllFollowersRecursive(rootLeader, {})
	return #allFollowers
end

-- Verificar quién debería ser dance leader
local function CheckDanceLeaders()
	local processedRoots = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player and player.Parent == Players then
			-- Obtener el líder raíz de este jugador
			local rootLeader = GetRootLeader(player)

			-- Evitar procesar el mismo líder raíz múltiples veces
			if rootLeader and not processedRoots[rootLeader] then
				processedRoots[rootLeader] = true

				-- Contar SOLO los seguidores del líder raíz
				local followerCount = GetFollowerCount(rootLeader)

				if followerCount >= FOLLOWER_DANCE_THRESHOLD then
					-- Si es nuevo líder, notificar
					if not CurrentDanceLeaders[rootLeader] then
						pcall(function()
							DanceLeaderEvent:FireClient(rootLeader, "setLeader", true)
							DanceLeaderEvent:FireAllClients("leaderAdded", rootLeader)
						end)
					end
					CurrentDanceLeaders[rootLeader] = true
				else
					-- Si dejó de ser líder
					if CurrentDanceLeaders[rootLeader] then
						pcall(function()
							DanceLeaderEvent:FireClient(rootLeader, "setLeader", false)
							DanceLeaderEvent:FireAllClients("leaderRemoved", rootLeader)
						end)
					end
					CurrentDanceLeaders[rootLeader] = nil
				end
			end
		end
	end

	-- Limpiar líderes que ya no existen
	for leader in pairs(CurrentDanceLeaders) do
		if not leader or leader.Parent ~= Players then
			CurrentDanceLeaders[leader] = nil
		end
	end
end

-- Tabla para rastrear conexiones de atributos por jugador
local PlayerConnections = {}

-- Manejar cuando un jugador hace respawn (comando ;re) o cambia personaje (;char)
local function OnCharacterAdded(player, character)
	-- Validar que el jugador sigue siendo válido
	if not player or player.Parent ~= Players then return end
	if not character or character.Parent == nil then return end

	-- Esperar a que el character se cargue completamente
	task.wait(0.5)

	-- Validar de nuevo después de esperar
	if not player or player.Parent ~= Players then return end

	-- Si este jugador es líder, notificar al cliente para recrear efectos
	if CurrentDanceLeaders[player] then
		pcall(function()
			DanceLeaderEvent:FireClient(player, "setLeader", true)
			DanceLeaderEvent:FireAllClients("leaderAdded", player)
		end)
	end
end

-- Conectar cambios en Sync.lua
-- Esperamos que Sync.lua actualice el atributo "followers" cuando hay cambios
local function OnPlayerAdded(player)
	-- Validar que el jugador es válido
	if not player or player.Parent ~= Players then return end

	-- Escuchar cambios en el atributo "followers" (que Sync.lua actualiza)
	local attrConnection = player:GetAttributeChangedSignal("followers"):Connect(function()
		CheckDanceLeaders()
	end)

	PlayerConnections[player] = {attrConnection}

	-- Escuchar cuando el jugador hace respawn (comando ;re de HD Admin)
	local charConnection = player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)
	table.insert(PlayerConnections[player], charConnection)

	-- Si ya tiene character, procesarlo (con validación)
	if player.Character then
		OnCharacterAdded(player, player.Character)
	end

	-- Verificar inmediatamente al conectar (para casos de refresco)
	CheckDanceLeaders()
end

local function OnPlayerRemoving(player)
	-- Limpiar todas las conexiones
	if PlayerConnections[player] then
		for _, connection in ipairs(PlayerConnections[player]) do
			pcall(function() connection:Disconnect() end)
		end
		PlayerConnections[player] = nil
	end

	-- Remover de líderes actuales
	CurrentDanceLeaders[player] = nil
end

-- Eventos
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Procesar jugadores que ya están en el servidor (para refrescos)
for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end

-- Verificar inmediatamente al inicio
CheckDanceLeaders()

-- Verificar periódicamente
while true do
	wait(CHECK_INTERVAL)
	CheckDanceLeaders()
end
