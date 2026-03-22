-- ════════════════════════════════════════════════════════════════
-- DJ MUSIC SYSTEM
-- by ignxts | refactored by Sistema
-- ════════════════════════════════════════════════════════════════

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local SoundService       = game:GetService("SoundService")

local MusicConfig    = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MusicSystemConfig"))

-- ════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ════════════════════════════════════════════════════════════════
local VIP_ID            = tonumber(MusicConfig.ACCESS and MusicConfig.ACCESS.VipGamepassId) or 0
local DEV_USER_ID       = 8387751399
local DEV_DISPLAY_NAME  = "Sistema"
local ASSET_PREFIX      = "rbxassetid://"
local DEFAULT_PITCH     = 1
local DEFAULT_VOLUME    = MusicConfig:GetDefaultVolume() or 0.5
local LOAD_TIMEOUT      = 12
local PLAY_CHECK_DELAY  = 0.5
local TRANSITION_DELAY  = 0.3
local MAX_RANDOM_RETRIES = 5

-- FIX 1: Tiempo de vida del caché de validación (segundos)
-- Las canciones validadas no necesitan re-validarse constantemente
local VALIDATION_CACHE_TTL = 300  -- 5 minutos
local VALIDATION_FAIL_TTL  = 60   -- 1 minuto para fallos (reintentar antes)

local RC = {
	SUCCESS      = "SUCCESS",
	INVALID_ID   = "ERROR_INVALID_ID",
	BLACKLISTED  = "ERROR_BLACKLISTED",
	DUPLICATE    = "ERROR_DUPLICATE",
	NOT_FOUND    = "ERROR_NOT_FOUND",
	NOT_AUTHORIZED = "ERROR_NOT_AUTHORIZED",
	QUEUE_FULL   = "ERROR_QUEUE_FULL",
	PERMISSION   = "ERROR_PERMISSION",
	COOLDOWN     = "ERROR_COOLDOWN",
	UNKNOWN      = "ERROR_UNKNOWN",
	EVENT_LOCKED = "ERROR_EVENT_LOCKED",
}

-- ════════════════════════════════════════════════════════════════
-- STATE
-- ════════════════════════════════════════════════════════════════
local musicDatabase   = {}
local djOrder         = {
	"Dj Dev"
}
local playQueue       = {}
local currentSongIndex = 1
local isPlaying       = false
local isPaused        = false
local isTransitioning = false
local currentPlayingId = nil
local metadataCache   = {}
local playerCooldowns = {}
local pitchLookup     = {}

-- FIX 1: Caché de validación de audio + deduplicación de requests en vuelo
local validationCache = {}   -- audioId -> { canPlay = bool, timestamp = number }
local validationInFlight = {} -- audioId -> { thread1, thread2, ... } (esperando resultado)

-- ════════════════════════════════════════════════════════════════
-- REMOTES
-- ════════════════════════════════════════════════════════════════
local remotesFolder = ReplicatedStorage:FindFirstChild("RemotesGlobal")
if not remotesFolder then warn("RemotesGlobal not found") return end

local function getRemote(folder, name)
	local f = remotesFolder:FindFirstChild(folder)
	return f and f:FindFirstChild(name)
end

local R = {
	Play            = getRemote("MusicPlayback", "PlaySong"),
	Next            = getRemote("MusicPlayback", "NextSong"),
	Stop            = getRemote("MusicPlayback", "StopSong"),
	ChangeVolume    = getRemote("MusicPlayback", "ChangeVolume"),
	Update          = getRemote("UI", "UpdateUI"),
	AddToQueue      = getRemote("MusicQueue", "AddToQueue"),
	AddResponse     = getRemote("MusicQueue", "AddToQueueResponse"),
	RemoveFromQueue = getRemote("MusicQueue", "RemoveFromQueue"),
	RemoveResponse  = getRemote("MusicQueue", "RemoveFromQueueResponse"),
	ClearQueue      = getRemote("MusicQueue", "ClearQueue"),
	ClearResponse   = getRemote("MusicQueue", "ClearQueueResponse"),
	PurchaseSkip    = getRemote("MusicQueue", "PurchaseSkip"),
	GetDJs          = getRemote("MusicLibrary", "GetDJs"),
	GetSongsByDJ    = getRemote("MusicLibrary", "GetSongsByDJ"),
	GetSongMetadata = getRemote("MusicLibrary", "GetSongMetadata"),
	SearchSongs     = getRemote("MusicLibrary", "SearchSongs"),
	GetSongRange    = getRemote("MusicLibrary", "GetSongRange"),
}

-- ════════════════════════════════════════════════════════════════
-- SOUND SETUP
-- ════════════════════════════════════════════════════════════════
local soundObject = workspace:FindFirstChild("SoundMG")
soundObject.Volume = DEFAULT_VOLUME
soundObject.Looped = false

local musicSoundGroup = SoundService:FindFirstChild("MusicSoundGroup")
if musicSoundGroup then soundObject.SoundGroup = musicSoundGroup end

-- ════════════════════════════════════════════════════════════════
-- PITCH MODULE
-- ════════════════════════════════════════════════════════════════
local function loadPitchModule()
	local pitchModuleScript = script.Parent:FindFirstChild("PitchModule")
	if not pitchModuleScript then return end
	local ok, pitchModule = pcall(require, pitchModuleScript)
	if not ok or type(pitchModule) ~= "table" or not pitchModule.ids then return end
	for _, entry in ipairs(pitchModule.ids) do
		if entry.id and entry.pitch then
			pitchLookup[ASSET_PREFIX .. tostring(entry.id)] = tonumber(entry.pitch) or DEFAULT_PITCH
		end
	end
end

local function applyPitch()
	soundObject.PlaybackSpeed = pitchLookup[soundObject.SoundId] or DEFAULT_PITCH
end

loadPitchModule()
soundObject:GetPropertyChangedSignal("SoundId"):Connect(function()
	task.delay(0.05, applyPitch)
end)

-- ════════════════════════════════════════════════════════════════
-- UTILITY LAYER
-- ════════════════════════════════════════════════════════════════
local function response(code, msg, data)
	return { code = code, success = code == RC.SUCCESS, message = msg, data = data or {}, timestamp = os.time() }
end

local function fireClient(remote, player, data)
	if remote then pcall(remote.FireClient, remote, player, data) end
end

local function adjustIndex()
	if currentSongIndex > #playQueue then
		currentSongIndex = 1
	end
end

local function getAllDJs()
	local list = {}
	for _, name in ipairs(djOrder) do
		local data = musicDatabase[name]
		if data then
			table.insert(list, {
				name      = name,
				cover     = data.cover or "",
				userId    = data.userId,
				songCount = #(data.songIds or {}),
			})
		end
	end
	return list
end

local function updateAllClients()
	if not R.Update then return end
	local currentSong = (#playQueue > 0 and currentSongIndex <= #playQueue) and playQueue[currentSongIndex] or nil
	local packet = {
		queue       = playQueue,
		currentSong = currentSong,
		djs         = getAllDJs(),
		isPlaying   = isPlaying,
		isPaused    = isPaused,
		currentIndex = currentSongIndex,
		queueLength = #playQueue,
		timestamp   = os.time(),
	}
	for _, p in ipairs(Players:GetPlayers()) do
		fireClient(R.Update, p, packet)
	end
end

-- ════════════════════════════════════════════════════════════════
-- PERMISSION LAYER
-- ════════════════════════════════════════════════════════════════
local function hasPermission(player, action)
	return MusicConfig:IsAdmin(player)
end

local function isEventBlocked(action, player)
	if not (_G.EventModeActive) then return false end
	if player and MusicConfig:IsAdmin(player) then return false end
	for _, blocked in ipairs(MusicConfig.EVENT_MODE.BlockedActions or {}) do
		if blocked == action then return true end
	end
	return false
end

local function checkAccess(player, action)
	if isEventBlocked(action, player) then
		return response(RC.EVENT_LOCKED, "Modo evento activo")
	end
	if not hasPermission(player, action) then
		return response(RC.PERMISSION, "Sin permiso")
	end
	return nil
end

-- ════════════════════════════════════════════════════════════════
-- DATABASE LAYER
-- ════════════════════════════════════════════════════════════════
local function loadDJs()
	musicDatabase = {}
	local rawDJs = MusicConfig:GetDJs()
	for name, data in pairs(rawDJs) do
		local ids = {}
		for _, id in ipairs(data.SongIds or {}) do
			if type(id) == "number" then table.insert(ids, id) end
		end
		musicDatabase[name] = {
			cover     = data.ImageId or "",
			userId    = data.userId,
			songIds   = ids,
			songCount = #ids,
		}
		local found = false
		for _, n in ipairs(djOrder) do if n == name then found = true break end end
		if not found then table.insert(djOrder, name) end
	end
end

local function findDJForSong(audioId)
	for djName, djData in pairs(musicDatabase) do
		for _, id in ipairs(djData.songIds or {}) do
			if id == audioId then return djName, djData.cover end
		end
	end
	return nil, nil
end

local function getRandomSongFromLibrary()
	local all = {}
	for djName, djData in pairs(musicDatabase) do
		for _, id in ipairs(djData.songIds or {}) do
			table.insert(all, { id = id, dj = djName, djCover = djData.cover })
		end
	end
	return #all > 0 and all[math.random(#all)] or nil
end

local function isInQueue(audioId)
	if MusicConfig.LIMITS.AllowDuplicatesInQueue then return false end
	for _, s in ipairs(playQueue) do
		if s.id == audioId then return true, s end
	end
	return false
end

-- ════════════════════════════════════════════════════════════════
-- METADATA LAYER
-- ════════════════════════════════════════════════════════════════
local function getOrLoadMetadata(audioId)
	local cached = metadataCache[audioId]
	if cached and cached.loaded and not cached.error then
		return cached.name, cached.artist, true
	end

	local djName = findDJForSong(audioId)
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, audioId, Enum.InfoType.Asset)

	if ok and info and info.AssetTypeId == 3 then
		local name   = info.Name or ("Audio " .. audioId)
		local artist = (info.Creator and info.Creator.Name) or "Unknown"
		metadataCache[audioId] = { name = name, artist = artist, loaded = true }
		return name, artist, true
	end

	if djName then
		return "Audio " .. audioId, djName, true
	end

	return nil, nil, false
end

local function loadMetadataBatch(ids, callback, perBatchCallback)
	if #ids == 0 then
		if callback then callback({}) end
		return
	end

	local BATCH_SIZE  = 10
	local BATCH_DELAY = 0.1
	local results = {}
	local pending = #ids

	for batchStart = 1, #ids, BATCH_SIZE do
		local batchEnd = math.min(batchStart + BATCH_SIZE - 1, #ids)
		local batchPending = batchEnd - batchStart + 1
		for i = batchStart, batchEnd do
			local id = ids[i]
			task.spawn(function()
				local name, artist, ok = getOrLoadMetadata(id)
				results[id] = ok
					and { name = name, artist = artist, loaded = true }
					or  { name = "Audio " .. id, artist = "Unknown", loaded = true, error = true }
				pending = pending - 1
				batchPending = batchPending - 1
				if batchPending == 0 and perBatchCallback then perBatchCallback(results) end
				if pending == 0 and callback then callback(results) end
			end)
		end
		if batchEnd < #ids then task.wait(BATCH_DELAY) end
	end
end

-- ════════════════════════════════════════════════════════════════
-- AUDIO PERMISSION VALIDATOR (con caché + deduplicación)
-- ════════════════════════════════════════════════════════════════

-- FIX 1: Validación real (solo se ejecuta cuando no hay caché válido)
local function _validateAudioPermissionRaw(audioId)
	local testSound = Instance.new("Sound")
	testSound.SoundId = ASSET_PREFIX .. audioId
	testSound.Volume  = 0
	testSound.Parent  = SoundService

	local canPlay, done = false, false
	local conn
	conn = testSound.Loaded:Connect(function()
		canPlay = testSound.TimeLength > 0
		done    = true
		conn:Disconnect()
	end)

	local deadline = tick() + 5
	while not done and tick() < deadline do
		task.wait(0.1)
		if testSound.IsLoaded and testSound.TimeLength > 0 then
			canPlay = true
			done    = true
		end
	end

	if conn then conn:Disconnect() end
	testSound:Destroy()
	return canPlay
end

-- FIX 1: Wrapper con caché y deduplicación de requests concurrentes
local function validateAudioPermission(audioId)
	-- 1. Revisar caché
	local cached = validationCache[audioId]
	if cached then
		local age = tick() - cached.timestamp
		local ttl = cached.canPlay and VALIDATION_CACHE_TTL or VALIDATION_FAIL_TTL
		if age < ttl then
			return cached.canPlay
		end
		-- Caché expirado, limpiar
		validationCache[audioId] = nil
	end

	-- 2. Si ya hay un request en vuelo para este ID, esperar su resultado
	--    en vez de crear OTRO Sound instance
	if validationInFlight[audioId] then
		local thread = coroutine.running()
		table.insert(validationInFlight[audioId], thread)
		-- Suspender este thread hasta que el request original termine
		local result = coroutine.yield()
		return result
	end

	-- 3. Somos el primer request para este ID, ejecutar validación real
	validationInFlight[audioId] = {}

	local canPlay = _validateAudioPermissionRaw(audioId)

	-- Guardar en caché
	validationCache[audioId] = {
		canPlay   = canPlay,
		timestamp = tick(),
	}

	-- Despertar todos los threads que estaban esperando este resultado
	local waitingThreads = validationInFlight[audioId]
	validationInFlight[audioId] = nil

	for _, thread in ipairs(waitingThreads) do
		task.spawn(function()
			coroutine.resume(thread, canPlay)
		end)
	end

	return canPlay
end

-- FIX 1b: Invalidar caché de un ID específico (útil si un audio falla al reproducir)
local function invalidateValidationCache(audioId)
	validationCache[audioId] = nil
end

local function hasVipGamepass(player)
	if VIP_ID <= 0 then
		return false
	end

	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, VIP_ID)
	if not ok then
		warn("[MusicSystem] Error verificando VIP para " .. player.Name)
		return false
	end

	return owns == true
end

-- ════════════════════════════════════════════════════════════════
-- QUEUE VALIDATION
-- ════════════════════════════════════════════════════════════════
local function getUserQueueLimit(player)
	if MusicConfig:IsAdmin(player) then
		return MusicConfig.LIMITS.MaxSongsPerUserAdmin, "Admin"
	elseif hasVipGamepass(player) then
		return MusicConfig.LIMITS.MaxSongsPerUserVIP, "VIP"
	end
	return MusicConfig.LIMITS.MaxSongsPerUserNormal, "Normal"
end

local function validateQueueAdd(player, audioId)
	-- 1. Cooldown (admins bypass)
	local now = tick()
	if not MusicConfig:IsAdmin(player) then
		local cooldown = MusicConfig.LIMITS.AddToQueueCooldown or 2
		local last = playerCooldowns[player.UserId]
		if last and (now - last) < cooldown then
			local wait = math.ceil(cooldown - (now - last))
			return nil, response(RC.COOLDOWN, "Espera " .. wait .. "s")
		end
	end

	-- 2. ID format
	local id = tonumber(audioId)
	local idStr = id and tostring(id) or ""
	if not id or #idStr < 6 or #idStr > 19 then
		return nil, response(RC.INVALID_ID, "ID inválido")
	end

	-- 3. Audio permission (verify audio can be loaded)
	if not validateAudioPermission(id) then
		return nil, response(RC.INVALID_ID, "Audio no disponible o sin permisos")
	end

	-- 4. Global queue cap
	if #playQueue >= MusicConfig.LIMITS.MaxQueueSize then
		return nil, response(RC.QUEUE_FULL, "Cola llena (" .. #playQueue .. "/" .. MusicConfig.LIMITS.MaxQueueSize .. ")")
	end

	-- 5. Per-user cap
	local limit, role = getUserQueueLimit(player)
	local userCount = 0
	for _, song in ipairs(playQueue) do
		if song.userId == player.UserId then userCount = userCount + 1 end
	end
	if userCount >= limit then
		return nil, response(RC.QUEUE_FULL, "Límite alcanzado (" .. userCount .. "/" .. limit .. " como " .. role .. ")")
	end

	-- 6. Duplicates (checar ANTES de metadata/validación para evitar trabajo innecesario)
	local dup, existing = isInQueue(id)
	if dup then
		return nil, response(RC.DUPLICATE, "Ya está en la cola", { songName = existing.name })
	end

	-- 7. Metadata (single call, usa caché interno)
	local name, artist, metaOk = getOrLoadMetadata(id)
	if not metaOk then return nil, response(RC.NOT_FOUND, "Audio no encontrado") end

	-- 8. Audio permission (ahora usa caché + deduplicación)
	if not validateAudioPermission(id) then
		return nil, response(RC.NOT_AUTHORIZED, "Audio bloqueado o sin permisos")
	end

	-- All clear
	playerCooldowns[player.UserId] = now
	return { id = id, name = name, artist = artist }, nil
end

-- ════════════════════════════════════════════════════════════════
-- PLAYBACK ENGINE
-- ════════════════════════════════════════════════════════════════
local playSong, nextSong, playRandomSong

local function cleanupSound()
	pcall(soundObject.Stop, soundObject)
	soundObject.SoundId      = ""
	soundObject.TimePosition = 0
	currentPlayingId = nil
end

local function stopSong()
	cleanupSound()
	isPlaying     = false
	isPaused      = false
	isTransitioning = false
	updateAllClients()
end

local function removeCurrentAndContinue()
	if currentSongIndex <= #playQueue then
		-- FIX 1b: Si falló al reproducir, invalidar su caché de validación
		local failedSong = playQueue[currentSongIndex]
		if failedSong then
			invalidateValidationCache(failedSong.id)
		end
		table.remove(playQueue, currentSongIndex)
	end
	adjustIndex()

	if #playQueue > 0 then
		task.defer(function() playSong(currentSongIndex) end)
	else
		task.defer(playRandomSong)
	end
end

playSong = function(index)
	cleanupSound()
	isTransitioning = false

	if #playQueue == 0 then
		isPlaying = false
		isPaused  = false
		updateAllClients()
		task.defer(playRandomSong)
		return
	end

	currentSongIndex = math.clamp(index or currentSongIndex, 1, #playQueue)
	local song = playQueue[currentSongIndex]
	currentPlayingId = song.id
	soundObject.Volume  = DEFAULT_VOLUME
	soundObject.SoundId = ASSET_PREFIX .. song.id

	local loaded      = false
	local thisPlayId  = song.id
	local loadConn

	local function startPlaying()
		if loaded or currentPlayingId ~= thisPlayId then
			if loadConn then loadConn:Disconnect() end
			return
		end
		loaded = true
		if loadConn then loadConn:Disconnect() end

		task.wait(0.15)

		if soundObject.TimeLength == 0 then
			removeCurrentAndContinue()
			return
		end

		soundObject.TimePosition = 0
		pcall(soundObject.Play, soundObject)
		isPlaying = true
		isPaused  = false
		updateAllClients()

		task.delay(PLAY_CHECK_DELAY, function()
			if currentPlayingId ~= thisPlayId or not isPlaying or isPaused then return end
			if soundObject.TimePosition >= 0.1 then return end

			pcall(function()
				soundObject:Stop()
				task.wait(0.1)
				soundObject.TimePosition = 0
				soundObject:Play()
			end)

			task.delay(PLAY_CHECK_DELAY, function()
				if currentPlayingId == thisPlayId and isPlaying and not isPaused then
					if soundObject.TimePosition < 0.1 then nextSong() end
				end
			end)
		end)
	end

	loadConn = soundObject.Loaded:Connect(startPlaying)

	task.defer(function()
		if not loaded and currentPlayingId == thisPlayId and soundObject.IsLoaded then
			startPlaying()
		end
	end)

	task.delay(LOAD_TIMEOUT, function()
		if not loaded and currentPlayingId == thisPlayId then
			loaded = true
			if loadConn then loadConn:Disconnect() end
			removeCurrentAndContinue()
		end
	end)
end

-- FIX 2: playRandomSong optimizado — usa caché de validación,
-- no re-valida canciones que ya sabemos que funcionan
playRandomSong = function()
	if #playQueue > 0 then
		currentSongIndex = 1
		task.defer(function() playSong(1) end)
		return
	end

	if isTransitioning then return end

	-- Construir lista de todas las canciones de la biblioteca
	local allSongs = {}
	for djName, djData in pairs(musicDatabase) do
		for _, id in ipairs(djData.songIds or {}) do
			table.insert(allSongs, { id = id, dj = djName, djCover = djData.cover })
		end
	end

	if #allSongs == 0 then
		warn("[playRandomSong] Biblioteca vacía")
		return
	end

	-- FIX 2: Primero intentar canciones que YA están validadas en caché
	-- Esto es instantáneo (0ms) en vez de 5s
	local shuffled = {}
	for i = #allSongs, 2, -1 do
		local j = math.random(i)
		allSongs[i], allSongs[j] = allSongs[j], allSongs[i]
	end

	-- Paso 1: Buscar entre las ya cacheadas como válidas (instantáneo)
	for _, song in ipairs(allSongs) do
		local cached = validationCache[song.id]
		if cached and cached.canPlay and (tick() - cached.timestamp) < VALIDATION_CACHE_TTL then
			local name, artist, metaOk = getOrLoadMetadata(song.id)
			if metaOk then
				table.insert(playQueue, {
					id          = song.id,
					name        = name,
					artist      = artist,
					userId      = DEV_USER_ID,
					requestedBy = DEV_DISPLAY_NAME,
					addedAt     = os.time(),
					dj          = song.dj,
					djCover     = song.djCover,
					isAutoPlay  = true,
				})
				currentSongIndex = 1
				task.delay(TRANSITION_DELAY, function() playSong(1) end)
				return
			end
		end
	end

	-- Paso 2: Si no hay cacheadas, validar como antes (con el caché nuevo para futuras)
	for attempt = 1, MAX_RANDOM_RETRIES do
		local randomSong = allSongs[math.random(#allSongs)]

		local name, artist, metaOk = getOrLoadMetadata(randomSong.id)
		local canPlay = metaOk and validateAudioPermission(randomSong.id)

		if canPlay then
			table.insert(playQueue, {
				id          = randomSong.id,
				name        = name,
				artist      = artist,
				userId      = DEV_USER_ID,
				requestedBy = DEV_DISPLAY_NAME,
				addedAt     = os.time(),
				dj          = randomSong.dj,
				djCover     = randomSong.djCover,
				isAutoPlay  = true,
			})
			currentSongIndex = 1
			task.delay(TRANSITION_DELAY, function() playSong(1) end)
			return
		end

		warn(string.format("[playRandomSong] Intento %d/%d falló para id=%s", attempt, MAX_RANDOM_RETRIES, randomSong.id))
		task.wait(0.1)
	end

	warn("[playRandomSong] No se encontró canción válida tras " .. MAX_RANDOM_RETRIES .. " intentos")
end

nextSong = function()
	if isTransitioning then return end
	isTransitioning = true

	cleanupSound()
	isPlaying = false
	isPaused  = false

	if #playQueue > 0 then
		table.remove(playQueue, currentSongIndex)
		adjustIndex()
	end

	updateAllClients()

	task.delay(#playQueue > 0 and TRANSITION_DELAY or 0.5, function()
		isTransitioning = false
		if #playQueue > 0 then
			playSong(currentSongIndex)
		else
			playRandomSong()
		end
	end)
end

-- ════════════════════════════════════════════════════════════════
-- QUEUE MANAGEMENT
-- ════════════════════════════════════════════════════════════════
local function removeFromQueue(index)
	if index < 1 or index > #playQueue then return false end
	local removed = table.remove(playQueue, index)

	if index == currentSongIndex then
		if #playQueue == 0 then
			stopSong()
			currentSongIndex = 1
			task.defer(playRandomSong)
		else
			adjustIndex()
			playSong(currentSongIndex)
		end
	elseif index < currentSongIndex then
		currentSongIndex = currentSongIndex - 1
		updateAllClients()
	else
		updateAllClients()
	end

	return true, removed.name
end

local function clearQueue()
	if #playQueue == 0 then return false, 0 end

	if isPlaying and currentSongIndex == 1 then
		local count = #playQueue - 1
		playQueue = { playQueue[1] }
		updateAllClients()
		return true, count
	end

	local count = #playQueue
	playQueue = {}
	currentSongIndex = 1
	stopSong()
	task.defer(playRandomSong)
	return true, count
end

-- ════════════════════════════════════════════════════════════════
-- SONG ENDED DETECTION
-- FIX 4: Polling como backup con intervalo más largo,
-- Ended como primario
-- ════════════════════════════════════════════════════════════════
soundObject.Ended:Connect(function()
	if isPlaying and not isTransitioning then nextSong() end
end)

-- Backup polling: solo para casos donde Ended no dispara
-- (audio corrupto, edge cases de Roblox)
task.spawn(function()
	while true do
		task.wait(1) -- FIX 4: Subido de 0.4s a 1s (Ended cubre el caso normal)
		if isPlaying and not isPaused and not isTransitioning then
			local len = soundObject.TimeLength
			local pos = soundObject.TimePosition
			if soundObject.SoundId ~= "" and len > 0 and currentPlayingId then
				if (len - pos) < 0.5 then
					nextSong()
					task.wait(2)
				end
			end
		end
	end
end)

-- ════════════════════════════════════════════════════════════════
-- LIBRARY HELPERS
-- ════════════════════════════════════════════════════════════════
local function getSongRange(djName, startIdx, endIdx)
	local dj = musicDatabase[djName]
	if not dj then return { songs = {}, total = 0 } end

	local ids = dj.songIds or {}
	startIdx = math.max(1, startIdx or 1)
	endIdx   = math.min(endIdx or (startIdx + 19), #ids)

	local songs, toLoad = {}, {}
	for i = startIdx, endIdx do
		local id = ids[i]
		if id then
			local c = metadataCache[id]
			table.insert(songs, {
				id      = id,
				index   = i,
				loaded  = c and c.loaded or false,
				name    = c and c.name   or "Cargando...",
				artist  = c and c.artist or ("ID: " .. id),
			})
			if not (c and c.loaded) then table.insert(toLoad, id) end
		end
	end

	return { songs = songs, total = #ids, startIndex = startIdx, endIndex = endIdx,
		hasMore = endIdx < #ids, idsToLoad = toLoad }
end

local function searchSongs(djName, query, maxResults)
	maxResults = maxResults or 50
	local dj = musicDatabase[djName]
	if not dj then return { songs = {}, total = 0, query = query } end

	local ids     = dj.songIds or {}
	local results = {}
	local qLower  = string.lower(query or "")
	local qNum    = tonumber(query)

	if qNum then
		for i, id in ipairs(ids) do
			if tostring(id):find(tostring(qNum), 1, true) then
				local c = metadataCache[id]
				table.insert(results, { id = id, index = i, loaded = c and c.loaded or false,
					name = c and c.name or ("Audio " .. id), artist = c and c.artist or "Unknown", matchType = "id" })
				if #results >= maxResults then break end
			end
		end
	end

	if #results < maxResults and qLower ~= "" then
		local seen = {}
		for _, r in ipairs(results) do seen[r.id] = true end
		for i, id in ipairs(ids) do
			if not seen[id] then
				local c = metadataCache[id]
				if c and c.loaded and c.name then
					local nameMatch   = string.lower(c.name):find(qLower, 1, true)
					local artistMatch = string.lower(c.artist or ""):find(qLower, 1, true)
					if nameMatch or artistMatch then
						table.insert(results, { id = id, index = i, loaded = true,
							name = c.name, artist = c.artist, matchType = "name" })
						if #results >= maxResults then break end
					end
				end
			end
		end
	end

	return { songs = results, total = #results, query = query, totalInDJ = #ids }
end

-- ════════════════════════════════════════════════════════════════
-- REMOTE HANDLERS
-- ════════════════════════════════════════════════════════════════

R.Play.OnServerEvent:Connect(function(player)
	if not hasPermission(player, "PlaySong") then return end
	if isPaused then
		pcall(soundObject.Resume, soundObject)
		isPaused  = false
		isPlaying = true
		updateAllClients()
	elseif #playQueue > 0 then
		playSong(currentSongIndex)
	else
		playRandomSong()
	end
end)

R.Next.OnServerEvent:Connect(function(player)
	local deny = checkAccess(player, "NextSong")
	if deny then return end
	print("Skip normal", player.DisplayName .. "(@" .. player.Name .. ")")
	nextSong()
end)

R.Stop.OnServerEvent:Connect(function(player)
	if not hasPermission(player, "StopSong") then return end
	stopSong()
end)

if R.ChangeVolume then
	R.ChangeVolume.OnServerEvent:Connect(function(player, volume)
		player:SetAttribute("MusicVolume", math.clamp(tonumber(volume) or 0.5, 0, 1))
	end)
end

local skipCooldowns = {}
local SKIP_COOLDOWN = MusicConfig.LIMITS.SkipCooldown or 30

if R.PurchaseSkip then
	R.PurchaseSkip.OnServerEvent:Connect(function(player)
		if isEventBlocked("NextSong", player) then
			pcall(R.PurchaseSkip.FireClient, R.PurchaseSkip, player, false, "Modo evento activo")
			return
		end

		local now = os.clock()
		local last = skipCooldowns[player.UserId]
		if last and (now - last) < SKIP_COOLDOWN then
			warn("[PurchaseSkip] Rate limit: " .. player.Name .. " (exploit detected)")
			pcall(R.PurchaseSkip.FireClient, R.PurchaseSkip, player, false, "Cooldown activo")
			return
		end
		skipCooldowns[player.UserId] = now

		print("Skip pagado por " .. player.DisplayName .. " (@" .. player.Name .. ")")
		nextSong()
		pcall(R.PurchaseSkip.FireClient, R.PurchaseSkip, player, true, "Canción saltada")
	end)
end

R.AddToQueue.OnServerEvent:Connect(function(player, audioId)
	-- Solo verificar event mode, no permisos de admin
	if isEventBlocked("AddToQueue", player) then
		return fireClient(R.AddResponse, player, response(RC.EVENT_LOCKED, "Modo evento activo"))
	end

	local songData, err = validateQueueAdd(player, audioId)
	if err then return fireClient(R.AddResponse, player, err) end

	-- FIX 3: El chequeo de duplicados ya se movió DENTRO de validateQueueAdd
	-- (antes del metadata/validación costosa), pero hacemos double-check
	-- justo antes de insertar por race conditions
	local dup, existing = isInQueue(songData.id)
	if dup then
		return fireClient(R.AddResponse, player, response(RC.DUPLICATE, "Ya está en la cola", { songName = existing.name }))
	end

	local djName, djCover = findDJForSong(songData.id)
	local songInfo = {
		id          = songData.id,
		name        = songData.name,
		artist      = songData.artist,
		userId      = player.UserId,
		requestedBy = player.Name,
		addedAt     = os.time(),
		dj          = djName,
		djCover     = djCover,
	}

	table.insert(playQueue, songInfo)
	fireClient(R.AddResponse, player, response(RC.SUCCESS, "Añadido", {
		songName = songInfo.name,
		artist   = songInfo.artist,
		position = #playQueue,
	}))
	updateAllClients()

	if not isPlaying and not isPaused and #playQueue == 1 then
		task.delay(TRANSITION_DELAY, function() playSong(1) end)
	end
end)

R.RemoveFromQueue.OnServerEvent:Connect(function(player, index)
	local deny = checkAccess(player, "RemoveFromQueue")
	if deny then return fireClient(R.RemoveResponse, player, deny) end

	local ok, name = removeFromQueue(index)
	fireClient(R.RemoveResponse, player, ok
		and response(RC.SUCCESS, "Eliminado", { songName = name })
		or  response(RC.INVALID_ID, "Índice inválido"))
end)

R.ClearQueue.OnServerEvent:Connect(function(player)
	local deny = checkAccess(player, "ClearQueue")
	if deny then return fireClient(R.ClearResponse, player, deny) end

	local ok, count = clearQueue()
	fireClient(R.ClearResponse, player, ok
		and response(RC.SUCCESS, "Limpiado", { clearedCount = count })
		or  response(RC.UNKNOWN, "Cola vacía"))
end)

R.GetDJs.OnServerEvent:Connect(function(player)
	fireClient(R.GetDJs, player, { djs = getAllDJs() })
end)

R.GetSongsByDJ.OnServerEvent:Connect(function(player, djName)
	local dj = musicDatabase[djName]
	fireClient(R.GetSongsByDJ, player, { djName = djName, total = dj and #(dj.songIds or {}) or 0, songs = {} })
end)

R.GetSongRange.OnServerEvent:Connect(function(player, djName, startIdx, endIdx)
	local result = getSongRange(djName, startIdx, endIdx)
	result.djName = djName
	fireClient(R.GetSongRange, player, result)

	if result.idsToLoad and #result.idsToLoad > 0 then
		loadMetadataBatch(result.idsToLoad, nil, function()
			local updated = getSongRange(djName, startIdx, endIdx)
			updated.djName   = djName
			updated.isUpdate = true
			fireClient(R.GetSongRange, player, updated)
		end)
	end
end)

R.SearchSongs.OnServerEvent:Connect(function(player, djName, query)
	local result = searchSongs(djName, query)
	result.djName = djName
	fireClient(R.SearchSongs, player, result)

	local idsToLoad = {}
	for _, song in ipairs(result.songs or {}) do
		if not (metadataCache[song.id] and metadataCache[song.id].loaded) then
			table.insert(idsToLoad, song.id)
		end
	end

	if #idsToLoad > 0 then
		loadMetadataBatch(idsToLoad, nil, function()
			local updated = searchSongs(djName, query)
			updated.djName   = djName
			updated.isUpdate = true
			fireClient(R.SearchSongs, player, updated)
		end)
	end
end)

R.GetSongMetadata.OnServerEvent:Connect(function(player, audioIds)
	if type(audioIds) ~= "table" then return end
	local results, toLoad = {}, {}
	for i = 1, math.min(#audioIds, 20) do
		local id = audioIds[i]
		if type(id) == "number" then
			local c = metadataCache[id]
			if c and c.loaded then
				results[id] = c
			else
				table.insert(toLoad, id)
				results[id] = { name = "Cargando...", artist = "ID: " .. id, loaded = false }
			end
		end
	end
	fireClient(R.GetSongMetadata, player, { metadata = results, pending = #toLoad })

	if #toLoad > 0 then
		loadMetadataBatch(toLoad, function(loaded)
			fireClient(R.GetSongMetadata, player, { metadata = loaded, pending = 0, isUpdate = true })
		end)
	end
end)

-- ════════════════════════════════════════════════════════════════
-- PLAYER EVENTS
-- ════════════════════════════════════════════════════════════════
Players.PlayerAdded:Connect(function()
	task.defer(updateAllClients)
end)

Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
	skipCooldowns[player.UserId] = nil
	-- Las canciones en cola se conservan aunque el jugador salga del juego
	updateAllClients()
end)

-- ════════════════════════════════════════════════════════════════
-- INIT
-- ════════════════════════════════════════════════════════════════
loadDJs()

-- FIX 2b: Pre-validar las primeras canciones de la biblioteca en background
-- para que playRandomSong sea instantáneo desde el inicio
task.spawn(function()
	task.wait(3) -- Esperar a que el servidor se estabilice
	local allSongs = {}
	for djName, djData in pairs(musicDatabase) do
		for _, id in ipairs(djData.songIds or {}) do
			table.insert(allSongs, id)
		end
	end
	-- Shuffle y pre-validar las primeras 20 (suficiente para autoplay inmediato)
	for i = #allSongs, 2, -1 do
		local j = math.random(i)
		allSongs[i], allSongs[j] = allSongs[j], allSongs[i]
	end
	local prevalidateCount = math.min(20, #allSongs)
	for i = 1, prevalidateCount do
		task.spawn(function()
			validateAudioPermission(allSongs[i])
		end)
		-- Espaciar para no saturar (5 concurrentes máximo)
		if i % 5 == 0 then task.wait(1) end
	end
end)

task.delay(1, function()
	updateAllClients()
	if #playQueue == 0 then playRandomSong() end
end)