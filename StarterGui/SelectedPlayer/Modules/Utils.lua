--[[
	═══════════════════════════════════════════════════════════
	UTILS - Utilidades reutilizables
	═══════════════════════════════════════════════════════════
	Funciones auxiliares para UI, avatares, colores, etc.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Utils = {}
local Config, State

-- Inicializar dependencias
function Utils.init(config, state)
	Config = config
	State = state
end

-- ═══════════════════════════════════════════════════════════════
-- TWEENING Y ANIMACIONES
-- ═══════════════════════════════════════════════════════════════

function Utils.tween(object, properties, duration, style)
	if not object or not object.Parent then return end
	local info = TweenInfo.new(duration or Config.ANIM_NORMAL, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(object, info, properties):Play()
end

-- ═══════════════════════════════════════════════════════════════
-- CREACIÓN DE UI
-- ═══════════════════════════════════════════════════════════════

function Utils.create(className, props)
	local instance = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then instance[k] = v end
	end
	if props.Parent then instance.Parent = props.Parent end
	return instance
end

function Utils.createFrame(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	return Utils.create("Frame", props)
end

function Utils.createLabel(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or Config.THEME.text
	return Utils.create("TextLabel", props)
end

function Utils.addCorner(parent, radius)
	return Utils.create("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function Utils.addStroke(parent, color, thickness, transparency)
	return Utils.create("UIStroke", {
		Color = color or Config.THEME.stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		Parent = parent
	})
end

-- ═══════════════════════════════════════════════════════════════
-- COLORES
-- ═══════════════════════════════════════════════════════════════

function Utils.darkenColor(color, amount)
	amount = math.clamp(amount or 0.2, 0, 1)
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Utils.darkenFullColor(color, amount)
	amount = math.clamp(amount or 0.93, 0, 1)
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Utils.getPlayerColor(targetPlayer, ColorEffects)
	if not ColorEffects or not targetPlayer then return Color3.fromRGB(255, 255, 255) end
	local colorName = targetPlayer:GetAttribute("SelectedColor") or "default"
	return ColorEffects.colors[colorName] or ColorEffects.defaultSelectedColor or Color3.fromRGB(0, 255, 0)
end

-- ═══════════════════════════════════════════════════════════════
-- AVATARES
-- ═══════════════════════════════════════════════════════════════

function Utils.getAvatarImage(userId)
	local cached = State.avatarCache[userId]
	if cached and (tick() - cached.time) < Config.AVATAR_CACHE_TIME then
		return cached.image
	end

	local success, result = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
	end)

	if success and result and result ~= "" then
		State.avatarCache[userId] = { image = result, time = tick() }
		return result
	end
	return ""
end

function Utils.asyncLoadAvatar(userId, imageLabel)
	if not userId or not imageLabel then return end

	task.spawn(function()
		local okLarge, largeUrl = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
		end)
		if okLarge and largeUrl and largeUrl ~= "" then
			State.avatarCache[userId] = { image = largeUrl, time = tick() }
			if imageLabel and imageLabel.Parent then
				pcall(function() imageLabel.Image = largeUrl end)
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- EFECTOS VISUALES
-- ═══════════════════════════════════════════════════════════════

function Utils.createRipple(button, container, x, y)
	if not button or not button.Parent or not container or not container.Parent then return end
	if not x or not y then return end

	local pos = button.AbsolutePosition
	if not pos then return end

	local ripple = Utils.createFrame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, x - pos.X, 0, y - pos.Y),
		Size = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundTransparency = 0.6,
		ZIndex = 1,
		Parent = container
	})
	Utils.addCorner(ripple, 999)

	local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.5
	Utils.tween(ripple, { Size = UDim2.new(0, maxSize, 0, maxSize), BackgroundTransparency = 1 }, 0.4, Enum.EasingStyle.Quad)
	task.delay(0.4, function() if ripple then ripple:Destroy() end end)
end

-- ═══════════════════════════════════════════════════════════════
-- CONEXIONES
-- ═══════════════════════════════════════════════════════════════

function Utils.addConnection(connection)
	table.insert(State.connections, connection)
	return connection
end

function Utils.clearConnections()
	for _, conn in ipairs(State.connections) do
		if conn and conn.Connected then conn:Disconnect() end
	end
	State.connections = {}
end

-- ═══════════════════════════════════════════════════════════════
-- DETECCIÓN DE JUGADOR
-- ═══════════════════════════════════════════════════════════════

function Utils.getPlayerFromPart(part)
	if not part then return nil end

	local current = part
	while current and current ~= workspace do
		local found = Players:GetPlayerFromCharacter(current)
		if found then return found end
		current = current.Parent
	end
	return nil
end

-- ═══════════════════════════════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════════════════════════════

function Utils.createScreenGui(parent)
	return Utils.create("ScreenGui", {
		Name = "UserPanel",
		ResetOnSpawn = false,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent
	})
end

-- ═══════════════════════════════════════════════════════════════
-- ACTUALIZACIÓN DE STATS
-- ═══════════════════════════════════════════════════════════════

function Utils.updateStats(data, excludeLikes, state)
	if not data or not state.statsLabels then return end
	for key, label in pairs(state.statsLabels) do
		if (not excludeLikes or key ~= "likes") and data[key] and label and label.Parent then
			label.Text = tostring(data[key] or 0)
		end
	end
end

function Utils.startAutoRefresh(state, remotes)
	if state.refreshThread then task.cancel(state.refreshThread) end

	state.refreshThread = task.spawn(function()
		while state.ui and state.userId do
			task.wait(Config.AUTO_REFRESH_INTERVAL)
			if not state.ui then break end

			local success, data = pcall(function()
				return remotes.Remotes.GetUserData:InvokeServer(state.userId)
			end)

			if success then Utils.updateStats(data, true, state) end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- HIGHLIGHT CON FADE OUT SUAVE
-- ═══════════════════════════════════════════════════════════════

local fadeOutTween = nil
local fadeInTween = nil
local highlightTransitionId = 0

local function cancelHighlightTweens()
	if fadeOutTween then pcall(function() fadeOutTween:Cancel() end) fadeOutTween = nil end
	if fadeInTween then pcall(function() fadeInTween:Cancel() end) fadeInTween = nil end
end

local function getHighlightColor(targetPlayer, ColorEffects)
	if not ColorEffects or not targetPlayer then
		return Color3.fromRGB(255, 255, 255)
	end

	return ColorEffects.colors[targetPlayer:GetAttribute("SelectedColor") or "default"]
		or ColorEffects.defaultSelectedColor
		or Color3.fromRGB(0, 255, 0)
end

-- ═══════════════════════════════════════════════════════════════
-- HIGHLIGHT (SUAVE CON BORDECITO)
-- ═══════════════════════════════════════════════════════════════

function Utils.setHighlightTarget(targetPlayer, state, ColorEffects)
	if not state or not state.highlight then return end

	highlightTransitionId = highlightTransitionId + 1
	local myTransitionId = highlightTransitionId
	cancelHighlightTweens()

	if _G.ShowSelectedHighlight == false then
		state.highlight.Enabled = false
		state.highlight.Adornee = nil
		return
	end

	if not targetPlayer or not targetPlayer.Character then
		if not state.highlight.Enabled then return end

		local fadeInfo = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		fadeOutTween = TweenService:Create(state.highlight, fadeInfo, {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})
		fadeOutTween:Play()
		fadeOutTween.Completed:Once(function()
			if myTransitionId ~= highlightTransitionId then
				return
			end
			if state.highlight then
				state.highlight.Adornee = nil
				state.highlight.Enabled = false
			end
			fadeOutTween = nil
		end)
		return
	end

	local color = getHighlightColor(targetPlayer, ColorEffects)

	-- Configurar colores y empezar invisible
	state.highlight.FillColor = color
	state.highlight.OutlineColor = color
	state.highlight.FillTransparency = 1
	state.highlight.OutlineTransparency = 1
	state.highlight.Adornee = targetPlayer.Character
	state.highlight.Enabled = true

	-- Fade-in suave: SOLO borde, sin relleno
	local fadeInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	fadeInTween = TweenService:Create(state.highlight, fadeInfo, {
		FillTransparency = 1,         -- sin relleno (invisible)
		OutlineTransparency = 0,      -- borde visible y limpio
	})
	fadeInTween:Play()
end

function Utils.attachHighlight(targetPlayer, state, ColorEffects)
	Utils.setHighlightTarget(targetPlayer, state, ColorEffects)
end

function Utils.detachHighlight(state)
	Utils.setHighlightTarget(nil, state)
end

return Utils
