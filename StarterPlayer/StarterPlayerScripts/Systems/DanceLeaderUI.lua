--[[
    Dance Leader System - CLIENT

    by ignxts
    25/01/2026
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("RemotesGlobal")
local Emotes_Sync = ReplicatedStorage:WaitForChild("Emotes_Sync")

local player = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════
-- CONFIGURACION
-- ══════════════════════════════════════════════════════════════════
local CONFIG = {
	-- Estrella
	STAR_HEIGHT_OFFSET = 5,
	STAR_SIZE = UDim2.new(2.5, 0, 2.5, 0),
	STAR_COLOR = Color3.fromRGB(255, 230, 100),
	STAR_GLOW_COLOR = Color3.fromRGB(255, 200, 50),

	-- Borde del jugador
	OUTLINE_COLOR = Color3.fromRGB(255, 215, 0),
	OUTLINE_TRANSPARENCY = 0,
	FILL_TRANSPARENCY = 0.70,

	-- Sparkles
	SPARKLE_COLOR = Color3.fromRGB(255, 230, 150),
	SPARKLE_RATE = 8,

	MAX_DISTANCE = 250,
}

-- ══════════════════════════════════════════════════════════════════
-- ASSETS
-- ══════════════════════════════════════════════════════════════════
local ASSETS = {
	STAR_IMAGE = "rbxassetid://127132480856895",
	STAR_GLOW = "rbxassetid://5864017498",
	SPARKLE_TEXTURE = "rbxassetid://2273224484",
}

-- ══════════════════════════════════════════════════════════════════
-- ESPERAR REMOTE EVENT
-- ══════════════════════════════════════════════════════════════════
local DanceLeaderEvent
local maxWaitTime = 10
local elapsedTime = 0

while not DanceLeaderEvent and elapsedTime < maxWaitTime do
	DanceLeaderEvent = Emotes_Sync:FindFirstChild("DanceLeaderEvent")
	if DanceLeaderEvent then break end
	task.wait(0.2)
	elapsedTime = elapsedTime + 0.2
end

if not DanceLeaderEvent then
	return
end

-- ══════════════════════════════════════════════════════════════════
-- CACHE DE EFECTOS
-- ══════════════════════════════════════════════════════════════════
local DanceLeaderEffects = {}

-- ══════════════════════════════════════════════════════════════════
-- FUNCION: Crear Estrella GUI Estatica
-- ══════════════════════════════════════════════════════════════════
local function CreateStarGUI(character)
	local head = character:FindFirstChild("Head")
	if not head then return nil end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DanceLeaderStarGUI"
	billboard.Size = CONFIG.STAR_SIZE
	billboard.StudsOffset = Vector3.new(0, CONFIG.STAR_HEIGHT_OFFSET, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = CONFIG.MAX_DISTANCE
	billboard.LightInfluence = 0
	billboard.Parent = head

	-- Glow exterior
	local glowOuter = Instance.new("ImageLabel")
	glowOuter.Name = "GlowOuter"
	glowOuter.Size = UDim2.new(2.5, 0, 2.5, 0)
	glowOuter.Position = UDim2.new(0.5, 0, 0.5, 0)
	glowOuter.AnchorPoint = Vector2.new(0.5, 0.5)
	glowOuter.BackgroundTransparency = 1
	glowOuter.Image = ASSETS.STAR_GLOW
	glowOuter.ImageColor3 = CONFIG.STAR_GLOW_COLOR
	glowOuter.ImageTransparency = 0.4
	glowOuter.Parent = billboard

	-- Glow medio
	local glowMid = Instance.new("ImageLabel")
	glowMid.Name = "GlowMid"
	glowMid.Size = UDim2.new(1.8, 0, 1.8, 0)
	glowMid.Position = UDim2.new(0.5, 0, 0.5, 0)
	glowMid.AnchorPoint = Vector2.new(0.5, 0.5)
	glowMid.BackgroundTransparency = 1
	glowMid.Image = ASSETS.STAR_GLOW
	glowMid.ImageColor3 = CONFIG.STAR_COLOR
	glowMid.ImageTransparency = 0.2
	glowMid.Parent = billboard

	-- Estrella principal
	local starImage = Instance.new("ImageLabel")
	starImage.Name = "StarMain"
	starImage.Size = UDim2.new(1, 0, 1, 0)
	starImage.Position = UDim2.new(0.5, 0, 0.5, 0)
	starImage.AnchorPoint = Vector2.new(0.5, 0.5)
	starImage.BackgroundTransparency = 1
	starImage.Image = ASSETS.STAR_IMAGE
	starImage.ImageColor3 = CONFIG.STAR_COLOR
	starImage.Parent = billboard

	-- Centro brillante
	local centerGlow = Instance.new("ImageLabel")
	centerGlow.Name = "CenterGlow"
	centerGlow.Size = UDim2.new(0.4, 0, 0.4, 0)
	centerGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
	centerGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	centerGlow.BackgroundTransparency = 1
	centerGlow.Image = ASSETS.STAR_GLOW
	centerGlow.ImageColor3 = Color3.fromRGB(255, 255, 255)
	centerGlow.Parent = billboard

	return billboard
end

-- ══════════════════════════════════════════════════════════════════
-- FUNCION: Crear Borde del Jugador
-- ══════════════════════════════════════════════════════════════════
local function CreatePlayerOutline(character)
	local highlight = Instance.new("Highlight")
	highlight.Name = "DanceLeaderOutline"
	highlight.Adornee = character
	highlight.FillColor = CONFIG.OUTLINE_COLOR
	highlight.FillTransparency = CONFIG.FILL_TRANSPARENCY
	highlight.OutlineColor = CONFIG.OUTLINE_COLOR
	highlight.OutlineTransparency = CONFIG.OUTLINE_TRANSPARENCY
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character

	return highlight
end

-- ══════════════════════════════════════════════════════════════════
-- FUNCION: Crear Sparkles
-- ══════════════════════════════════════════════════════════════════
local function CreateSparkles(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "DanceLeaderSparkles"
	sparkles.Texture = ASSETS.SPARKLE_TEXTURE
	sparkles.Rate = CONFIG.SPARKLE_RATE
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.SpreadAngle = Vector2.new(360, 360)
	sparkles.RotSpeed = NumberRange.new(-45, 45)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	})
	sparkles.LightEmission = 1
	sparkles.LightInfluence = 0
	sparkles.Color = ColorSequence.new(CONFIG.SPARKLE_COLOR)
	sparkles.Parent = hrp

	return sparkles
end

-- ══════════════════════════════════════════════════════════════════
-- FUNCION: Remover Efectos
-- ══════════════════════════════════════════════════════════════════
local function RemoveDanceLeaderEffects(targetPlayer)
	local data = DanceLeaderEffects[targetPlayer]
	if not data then return end

	for _, instance in ipairs(data.instances) do
		if instance and instance.Parent then
			instance:Destroy()
		end
	end

	DanceLeaderEffects[targetPlayer] = nil
end

-- ══════════════════════════════════════════════════════════════════
-- FUNCION PRINCIPAL: Crear Efectos
-- ══════════════════════════════════════════════════════════════════
local function CreateDanceLeaderEffects(targetPlayer, waitForCharacter)
	if not targetPlayer then return end

	-- Si se solicita, esperar a que el character esté listo (para ;char/;unchar)
	if waitForCharacter then
		local maxWait = 0
		while (not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("Head")) and maxWait < 20 do
			task.wait(0.1)
			maxWait = maxWait + 1
		end
	end

	if not targetPlayer.Character then return end

	if DanceLeaderEffects[targetPlayer] then
		RemoveDanceLeaderEffects(targetPlayer)
	end

	local character = targetPlayer.Character
	local head = character:FindFirstChild("Head")
	if not head then return end

	local effectsData = {
		instances = {}
	}

	-- Crear Estrella
	local starBillboard = CreateStarGUI(character)
	if starBillboard then
		table.insert(effectsData.instances, starBillboard)
	end

	-- Crear Borde
	local highlight = CreatePlayerOutline(character)
	if highlight then
		table.insert(effectsData.instances, highlight)
	end

	-- Crear Sparkles
	local sparkles = CreateSparkles(character)
	if sparkles then
		table.insert(effectsData.instances, sparkles)
	end

	DanceLeaderEffects[targetPlayer] = effectsData
end

-- ══════════════════════════════════════════════════════════════════
-- VERIFICAR ESTADO INICIAL (para casos de refresco)
-- ══════════════════════════════════════════════════════════════════
local function CheckInitialState()
	-- Verificar si ya somos líder (útil cuando nos refrescamos con HD Admin)
	local character = player.Character
	if not character then return end

	-- Buscar si ya tenemos efectos de líder en el personaje
	local hasLeaderEffects = character:FindFirstChild("DanceLeaderOutline") or 
		(character:FindFirstChild("Head") and character.Head:FindFirstChild("DanceLeaderStarGUI"))

	if not hasLeaderEffects then
		-- Esperar un momento a que el servidor nos notifique si somos líder
		task.wait(1)
		-- Nota: El servidor ahora verificará automáticamente al inicio
	end
end

-- Ejecutar verificación inicial
if player.Character then
	CheckInitialState()
end

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	CheckInitialState()
end)

-- ══════════════════════════════════════════════════════════════════
-- EVENTOS
-- ══════════════════════════════════════════════════════════════════
DanceLeaderEvent.OnClientEvent:Connect(function(action, ...)
	if action == "setLeader" then
		local isLeader = (...)
		if isLeader then
			-- Esperar al character si es necesario (para ;char/;unchar)
			CreateDanceLeaderEffects(player, true)
		else
			RemoveDanceLeaderEffects(player)
		end

	elseif action == "leaderAdded" then
		local targetPlayer = (...)
		-- Procesar todos los líderes, incluyéndonos (importante para ;char/;unchar)
		if targetPlayer == player then
			CreateDanceLeaderEffects(targetPlayer, true)
		else
			CreateDanceLeaderEffects(targetPlayer, false)
		end

	elseif action == "leaderRemoved" then
		local targetPlayer = (...)
		RemoveDanceLeaderEffects(targetPlayer)
	end
end)

player.CharacterRemoving:Connect(function()
	for targetPlayer, _ in pairs(DanceLeaderEffects) do
		RemoveDanceLeaderEffects(targetPlayer)
	end
end)

Players.PlayerRemoving:Connect(function(leavingPlayer)
	RemoveDanceLeaderEffects(leavingPlayer)
end)