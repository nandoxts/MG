--[[
	═══════════════════════════════════════════════════════════
	PANEL VIEW - Construcción visual del UserPanel
	═══════════════════════════════════════════════════════════
	• Glassmorphism, DevSystem, Avatar, Botones, Dynamic Section
	• Panel creation/destruction centralizado
	• Optimizado: cache de layout, batch tweens, defer visual
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local PanelView = {}

-- ═══════════════════════════════════════════════════════════════
-- DEPENDENCIAS (inyectadas via init)
-- ═══════════════════════════════════════════════════════════════
local Config, State, Utils, Remotes
local Services, NotificationSystem, ColorEffects, THEME
local player, playerGui
local PREMIUM_ICON = "rbxassetid://13600832988"

-- Cache de layout por sesión de panel (evita recalcular)
local cachedLayout = nil
local activeTweens = {}
local adminRotationConns = {}

function PanelView.init(config, state, utils, remotes)
	Config = config
	State = state
	Utils = utils
	Remotes = remotes
	Services = remotes.Services
	NotificationSystem = remotes.Systems.NotificationSystem
	ColorEffects = remotes.Systems.ColorEffects
	THEME = config.THEME
	PREMIUM_ICON = config.PREMIUM_ICON or PREMIUM_ICON
	player = Services.Player
	playerGui = Services.PlayerGui
end

-- ═══════════════════════════════════════════════════════════════
-- LAYOUT CACHE (solo recalcula si cambia dispositivo)
-- ═══════════════════════════════════════════════════════════════
local lastDeviceType = nil

local function detectDevice()
	local UIS = game:GetService("UserInputService")
	local touch = UIS.TouchEnabled
	local mouseOn = UIS.MouseEnabled
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	if touch and not mouseOn then
		return vp.X >= 1024 and "tablet" or "mobile"
	end
	return "desktop"
end

local function getLayout()
	local device = detectDevice()
	if cachedLayout and device == lastDeviceType then return cachedLayout end
	lastDeviceType = device

	if device == "mobile" then
		local ph = Config.PANEL_HEIGHT - 20
		cachedLayout = {
			panelWidth = math.min(Config.PANEL_WIDTH, 280),
			panelHeight = ph,
			avatarHeight = ph,   -- siempre igual al panel visible
			buttonHeight = Config.BUTTON_HEIGHT - 2,
			buttonGap = Config.BUTTON_GAP,
			panelPadding = math.max(Config.PANEL_PADDING - 2, 6),
			fontSize = { title = 14, subtitle = 9, stat = 11, statLabel = 7, button = 12 },
			dragHandleH = 24, cardSize = Config.CARD_SIZE - 4,
			statsWidth = Config.STATS_WIDTH - 8, cornerRadius = 14,
			bottomOffset = 60, likeButtonSize = 22,
		}
	elseif device == "tablet" then
		local ph = Config.PANEL_HEIGHT
		cachedLayout = {
			panelWidth = Config.PANEL_WIDTH + 20,
			panelHeight = ph,
			avatarHeight = ph,   -- siempre igual al panel visible
			buttonHeight = Config.BUTTON_HEIGHT,
			buttonGap = Config.BUTTON_GAP,
			panelPadding = Config.PANEL_PADDING,
			fontSize = { title = 17, subtitle = 11, stat = 14, statLabel = 8, button = 13 },
			dragHandleH = 20, cardSize = Config.CARD_SIZE,
			statsWidth = Config.STATS_WIDTH, cornerRadius = 14,
			bottomOffset = 80, likeButtonSize = 26,
		}
	else
		local ph = Config.PANEL_HEIGHT
		cachedLayout = {
			panelWidth = Config.PANEL_WIDTH,
			panelHeight = ph,
			avatarHeight = ph,   -- siempre igual al panel visible
			buttonHeight = Config.BUTTON_HEIGHT,
			buttonGap = Config.BUTTON_GAP,
			panelPadding = Config.PANEL_PADDING,
			fontSize = { title = 18, subtitle = 13, stat = 16, statLabel = 9, button = 14 },
			dragHandleH = 18, cardSize = Config.CARD_SIZE,
			statsWidth = Config.STATS_WIDTH, cornerRadius = 12,
			bottomOffset = 90, likeButtonSize = 28,
		}
	end
	return cachedLayout
end

PanelView.getLayout = getLayout

-- ═══════════════════════════════════════════════════════════════
-- TWEEN HELPER (cancelación automática por instancia)
-- ═══════════════════════════════════════════════════════════════
local function safeTween(inst, props, duration, style, dir)
	if not inst or not inst.Parent then return end
	local key = tostring(inst)
	local prev = activeTweens[key]
	if prev then prev:Cancel() end
	local tw = Utils.tween(inst, props, duration or Config.ANIM_FAST, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut)
	activeTweens[key] = tw
	return tw
end

PanelView.safeTween = safeTween

-- ═══════════════════════════════════════════════════════════════
-- ADMIN SYSTEM (desde AdminConfig)
-- ═══════════════════════════════════════════════════════════════
local Admin = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdminConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AdminConfig"))
local ModernScrollbar = require(ReplicatedStorage:WaitForChild("UIComponents"):WaitForChild("ModernScrollbar"))
local UI = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("UI"))

function Admin.isAdmin(userName)
	-- Acepta nombre de usuario (string)
	if not userName then return false end
	return AdminConfig:IsAdmin(userName)
end

function Admin.getBadgeInfo(userName, baseColor)
	if not Admin.isAdmin(userName) then return nil end
	baseColor = baseColor or THEME.accent
	return {
		text = "OWNER", color = baseColor,
		glowColor = baseColor,
	}
end

function Admin.applyBorderGradient(stroke, speed, baseColor)
	speed = speed or 1.5
	baseColor = baseColor or Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Parent = stroke
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, baseColor),
		ColorSequenceKeypoint.new(0.33, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.66, baseColor),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	local elapsed = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		if not stroke.Parent then return end
		elapsed = elapsed + (dt * speed * 60)
		gradient.Rotation = elapsed % 360
	end)
	table.insert(adminRotationConns, conn)
	Utils.addConnection(conn)
	return gradient
end

function Admin.createBadge(parent, badgeInfo, L)
	local badge = Utils.createFrame({ Size = UDim2.new(0, 48, 0, 18), BackgroundColor3 = badgeInfo.color, BackgroundTransparency = 0.45, Parent = parent })
	Utils.addCorner(badge, 9)
	Utils.addStroke(badge, badgeInfo.glowColor, 1, 0.4)
	Utils.createLabel({ Size = UDim2.new(1, 0, 1, 0), Text = badgeInfo.text, TextColor3 = THEME.text, TextSize = L.fontSize.statLabel + 1, Font = Enum.Font.GothamBlack, Parent = badge })
	return badge
end

PanelView.Admin = Admin

-- ═══════════════════════════════════════════════════════════════
-- PANEL BACKGROUND (sólido, sin glass)
-- ═══════════════════════════════════════════════════════════════
local function applyGlass(container, playerColor, L, isAdmin)
	Utils.createFrame({ Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = THEME.bg, BackgroundTransparency = 0, ZIndex = 0, Parent = container })
end

-- ═══════════════════════════════════════════════════════════════
-- BOTÓN SÓLIDO
-- ═══════════════════════════════════════════════════════════════
local function createButton(parent, text, layoutOrder, accentColor)
	local L = getLayout()
	local container = Utils.createFrame({ Size = UDim2.new(1, 0, 0, L.buttonHeight), LayoutOrder = layoutOrder, Parent = parent })

	local btn = Utils.create("TextButton", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = THEME.card, BackgroundTransparency = 0,
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = container
	})
	Utils.addCorner(btn, 999)

	local stroke = Utils.create("UIStroke", {
		Color = accentColor or THEME.accent,
		Thickness = 0.75,
		Transparency = 0.78,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = btn,
	})

	local rippleCont = Utils.createFrame({ Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true, Parent = btn })
	Utils.addCorner(rippleCont, 999)

	local label = Utils.createLabel({ Size = UDim2.new(1, 0, 1, 0), Text = text, TextSize = L.fontSize.button, Font = Enum.Font.GothamBold, TextColor3 = THEME.text, Parent = btn })

	Utils.addConnection(btn.MouseEnter:Connect(function()
		safeTween(btn, { BackgroundColor3 = THEME.elevated, BackgroundTransparency = 0 }, Config.ANIM_FAST)
		safeTween(stroke, { Transparency = 0.45, Thickness = 1 }, Config.ANIM_FAST)
	end))
	Utils.addConnection(btn.MouseLeave:Connect(function()
		safeTween(btn, { BackgroundColor3 = THEME.card, BackgroundTransparency = 0 }, Config.ANIM_FAST)
		safeTween(stroke, { Transparency = 0.78, Thickness = 0.75 }, Config.ANIM_FAST)
	end))
	Utils.addConnection(btn.MouseButton1Click:Connect(function(x, y) Utils.createRipple(btn, rippleCont, x, y) end))

	return btn, label
end

-- ═══════════════════════════════════════════════════════════════
-- DONATION OVERLAY (Mini-panel flotante sobre el panel)
-- ═══════════════════════════════════════════════════════════════

local function closeDonationOverlay()
	local content = State.donationOverlay
	if not content or not content.Parent then
		State.donationOverlay = nil
		State.isLoadingDynamic = false
		return
	end

	if content:GetAttribute("Closing") then return end
	content:SetAttribute("Closing", true)

	local L = getLayout()
	local contentH = L.cardSize + 86
	-- Sale por abajo del CanvasGroup (se recorta automáticamente)
	local hideY = L.panelHeight + contentH

	safeTween(content, {
		Position = UDim2.new(0.5, 0, 0, hideY),
	}, 0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)

	task.delay(0.57, function()
		if content and content.Parent then content:Destroy() end
		if State.donationOverlay == content then
			State.donationOverlay = nil
		end
		State.isLoadingDynamic = false
	end)
end

local function showDonationOverlay(items, targetName, playerColor)
	local L = getLayout()

	if State.donationOverlay then
		closeDonationOverlay()
		task.wait(0.6)
	end

	local parent = State.panelContainer
	if not parent then return end

	local contentH = L.cardSize + 86
	-- Posiciones relativas al panelContainer (CanvasGroup que recorta)
	local centerY = L.panelHeight / 2
	local startY = L.panelHeight + contentH

	-- Panel flotante directo (sin overlay backdrop)
	local content = Utils.create("CanvasGroup", {
		Name = "DonationContent",
		Size = UDim2.new(1, -L.panelPadding * 2, 0, contentH),
		Position = UDim2.new(0.5, 0, 0, startY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = THEME.bg,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 100,
		GroupTransparency = 0,
		Parent = parent,
	})
	Utils.addCorner(content, L.cornerRadius)
	Utils.addStroke(content, THEME.stroke, 1.6, 0.25)
	State.donationOverlay = content

	-- Header
	local headerH = 36
	local headerFrame = Utils.createFrame({
		Size = UDim2.new(1, 0, 0, headerH),
		ZIndex = 101, Parent = content,
	})

	-- Botón BACK (outlined circle)
	local backBtn, backIcon = UI.outlinedCircleBtn(headerFrame, {
		size = 26,
		icon = UI.ICONS.BACK,
		theme = THEME,
		zIndex = 102,
		position = UDim2.new(0, L.panelPadding, 0.5, -13),
		name = "BackBtn",
	})
	Utils.addConnection(backBtn.MouseButton1Click:Connect(closeDonationOverlay))

	-- Hover sutil en el icono
	Utils.addConnection(backBtn.MouseEnter:Connect(function()
		safeTween(backIcon, { ImageColor3 = THEME.text }, Config.ANIM_FAST)
	end))
	Utils.addConnection(backBtn.MouseLeave:Connect(function()
		safeTween(backIcon, { ImageColor3 = THEME.dim }, Config.ANIM_FAST)
	end))

	-- Título
	Utils.createLabel({
		Size = UDim2.new(1, -(L.panelPadding * 2 + 34), 0, headerH),
		Position = UDim2.new(0, L.panelPadding + 34, 0, 0),
		Text = "Donar a " .. (targetName or "Usuario"),
		TextColor3 = THEME.text,
		TextSize = L.fontSize.title - 2,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 101, Parent = headerFrame,
	})

	-- Scroll horizontal de items
	local scrollTop = headerH + 6
	local scroll = Utils.create("ScrollingFrame", {
		Size = UDim2.new(1, -L.panelPadding * 2, 1, -scrollTop - 8),
		Position = UDim2.new(0, L.panelPadding, 0, scrollTop),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = playerColor or THEME.accent,
		ScrollBarImageTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(0, 0, 0, L.cardSize + 14),
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ZIndex = 101, Parent = content,
	})
	Utils.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 10), Parent = scroll })

	if not items or #items == 0 then
		Utils.createLabel({ Size = UDim2.new(1, 0, 1, 0), Text = "No hay items disponibles", TextColor3 = THEME.muted, TextSize = L.fontSize.statLabel + 2, ZIndex = 101, Parent = scroll })
	else
		for i, item in ipairs(items) do
			local cardOuter = Utils.createFrame({ Size = UDim2.new(0, L.cardSize + 10, 0, L.cardSize + 10), LayoutOrder = i, ZIndex = 101, Parent = scroll })

			-- CanvasGroup circular para recorte limpio de imagen
			local circle = Utils.create("CanvasGroup", {
				Size = UDim2.new(0, L.cardSize, 0, L.cardSize),
				Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = THEME.card, BackgroundTransparency = 0,
				BorderSizePixel = 0,
				ZIndex = 101, Parent = cardOuter,
			})
			Utils.addCorner(circle, L.cardSize / 2)
			local circleStroke = Utils.addStroke(circle, THEME.stroke, 1.5)

			Utils.create("ImageLabel", {
				Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
				Image = item.icon or "", ScaleType = Enum.ScaleType.Crop,
				ZIndex = 102, Parent = circle,
			})

			local priceOverlay = Utils.createFrame({
				Size = UDim2.new(1, 0, 0.4, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(10, 10, 15), BackgroundTransparency = 0.35,
				ZIndex = 103, ClipsDescendants = true, Parent = circle,
			})
			Utils.addCorner(priceOverlay, 8)

			local priceText = Utils.createLabel({
				Size = UDim2.new(1, 0, 1, 0),
				Text = utf8.char(0xE002) .. tostring(item.price or 0),
				TextColor3 = THEME.accent, TextSize = 12, Font = Enum.Font.GothamBold,
				ZIndex = 104, Parent = priceOverlay,
			})

			if item.hasPass == true then
				priceText.Text = "ADQUIRIDO"
				priceText.TextColor3 = Color3.fromRGB(100, 220, 100)
				priceOverlay.BackgroundTransparency = 0.4
			elseif item.hasPass == nil and item.passId then
				task.spawn(function()
					local ok, result = pcall(function()
						return Remotes.Remotes.CheckGamePass:InvokeServer(item.passId)
					end)
					item.hasPass = (ok and result) or false
					if item.hasPass and priceText.Parent then
						priceText.Text = "ADQUIRIDO"
						priceText.TextColor3 = Color3.fromRGB(100, 220, 100)
						priceOverlay.BackgroundTransparency = 0.4
					end
				end)
			end

			local clickBtn = Utils.create("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 105, Parent = cardOuter })
			local strokeHover = playerColor or THEME.accent

			Utils.addConnection(clickBtn.MouseEnter:Connect(function()
				safeTween(circleStroke, { Color = strokeHover, Thickness = 2.5 }, Config.ANIM_FAST)
			end))
			Utils.addConnection(clickBtn.MouseLeave:Connect(function()
				safeTween(circleStroke, { Color = THEME.stroke, Thickness = 1.5 }, Config.ANIM_FAST)
			end))

			Utils.addConnection(clickBtn.MouseButton1Click:Connect(function()
				if item.hasPass == true then
					if NotificationSystem then
						NotificationSystem:Info("Game Pass", "Ya compraste este pase", 2)
					end
				elseif item.passId then
					pcall(function() Services.MarketplaceService:PromptGamePassPurchase(player, item.passId) end)
				end
			end))
		end
	end

	-- Animación de entrada: sube desde fuera del panel hasta el centro (igual que el panel principal)
	safeTween(content, {
		Position = UDim2.new(0.5, 0, 0, centerY),
	}, 0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	task.delay(0.65, function() State.isLoadingDynamic = false end)
end

-- ═══════════════════════════════════════════════════════════════
-- BUTTONS SECTION
-- ═══════════════════════════════════════════════════════════════
local function createButtonsSection(panel, target, playerColor)
	local L = getLayout()
	State.panel = panel

	local startY = L.avatarHeight + L.buttonGap
	local numBtns = 3
	local btnsH = (L.buttonHeight * numBtns) + (L.buttonGap * (numBtns - 1))

	State.buttonsFrame = Utils.createFrame({ Size = UDim2.new(1, -2 * L.panelPadding, 0, btnsH + 8), Position = UDim2.new(0, L.panelPadding, 0, startY), ZIndex = 5, Parent = panel })
	Utils.create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, L.buttonGap), Parent = State.buttonsFrame })

	local SyncSystem = require(script.Parent.SyncSystem)
	local LikesSystem = require(script.Parent.LikesSystem)

	-- 1. Sincronizar
	local syncBtn = createButton(State.buttonsFrame, "Sincronizar", 1, playerColor)
	local syncDebounce = false
	Utils.addConnection(syncBtn.MouseButton1Click:Connect(function()
		if syncDebounce or not target then return end
		syncDebounce = true
		SyncSystem.syncWithPlayer(target)
		task.wait(0.5); syncDebounce = false
	end))

	-- 2. Ver Perfil
	local profileBtn = createButton(State.buttonsFrame, "Ver Perfil", 2, playerColor)
	Utils.addConnection(profileBtn.MouseButton1Click:Connect(function()
		if target then pcall(function() Services.GuiService:InspectPlayerFromUserId(target.UserId) end) end
	end))

	-- 3. Donar
	local donateBtn, donateLabel = createButton(State.buttonsFrame, "Donar", 3, playerColor)
	Utils.addConnection(donateBtn.MouseButton1Click:Connect(function()
		if not State.userId or State.isLoadingDynamic or State.donationOverlay then return end
		State.isLoadingDynamic = true
		donateBtn.Active = false; donateLabel.Text = "Cargando..."
		safeTween(donateBtn, { BackgroundTransparency = 0.5 }, Config.ANIM_FAST)

		task.spawn(function()
			local ok, donations = pcall(function() return Remotes.Remotes.GetUserDonations:InvokeServer(State.userId) end)
			if donateBtn and donateBtn.Parent then
				donateBtn.Active = true; donateLabel.Text = "Donar"
				safeTween(donateBtn, { BackgroundTransparency = 0.15 }, Config.ANIM_FAST)
			end
			if ok and donations then
				showDonationOverlay(donations, target and target.DisplayName, playerColor)
			else
				State.isLoadingDynamic = false
				if NotificationSystem then NotificationSystem:Error("Error", "No se pudo cargar donaciones", 2) end
			end
		end)
	end))

end

-- ═══════════════════════════════════════════════════════════════
-- AVATAR SECTION
-- ═══════════════════════════════════════════════════════════════
local function createAvatarSection(panel, data, playerColor)
	local L = getLayout()
	local isAdmin = Admin.isAdmin(data.username)
	local isPremium = (data and data.isPremium == true) or (State.target and State.target.MembershipType == Enum.MembershipType.Premium)
	local badgeInfo = Admin.getBadgeInfo(data.username, playerColor)
	local LikesSystem = require(script.Parent.LikesSystem)

	local avatarSection = Utils.createFrame({ Size = UDim2.new(1, 0, 0, L.avatarHeight), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3, Parent = panel })

	-- Avatar
	local avatarImage = Utils.create("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = data.avatar or "", ScaleType = Enum.ScaleType.Crop, ZIndex = 3, Parent = avatarSection
	})
	Utils.asyncLoadAvatar(data.userId, avatarImage)

	-- Stats sidebar
	local statsBar = Utils.createFrame({
		Size = UDim2.new(0, L.statsWidth, 1, 0), Position = UDim2.new(1, -L.statsWidth, 0, 0),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12), BackgroundTransparency = 1, ZIndex = 10,
		ClipsDescendants = true, Parent = avatarSection
	})
	Utils.addCorner(statsBar, L.cornerRadius)

	Utils.create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), Parent = statsBar })

	for _, stat in ipairs({ { key = "followers", label = "FOLLOW" }, { key = "friends", label = "FRIENDS" }, { key = "likes", label = "LIKES" } }) do
		local sc = Utils.createFrame({ Size = UDim2.new(1, -8, 0, Config.STATS_ITEM_HEIGHT), ZIndex = 11, Parent = statsBar })
		Utils.addCorner(sc, 6)
		State.statsLabels[stat.key] = Utils.createLabel({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 4), Text = tostring(data[stat.key] or 0), TextColor3 = THEME.text, TextSize = L.fontSize.stat, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0.75, ZIndex = 11, Parent = sc })
		Utils.createLabel({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 26), Text = stat.label, TextColor3 = THEME.muted, TextSize = L.fontSize.statLabel + 1, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0.82, ZIndex = 11, Parent = sc })
	end

	-- Nombres
	local nameY = isAdmin and -50 or -46
	local nameMain = Utils.createFrame({ Size = UDim2.new(1, -L.statsWidth - 16, 0, 36), Position = UDim2.new(0, 10, 1, nameY), BackgroundTransparency = 1, ZIndex = 25, Parent = avatarSection })
	Utils.create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 0), Parent = nameMain })

	local nameCont = Utils.createFrame({ Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1, Parent = nameMain })
	Utils.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2), Parent = nameCont })

	local dnLabel = Utils.createLabel({ Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = data.displayName, TextColor3 = playerColor, TextSize = L.fontSize.title, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1, Parent = nameCont })

	if isPremium then
		local premiumSize = math.max(L.fontSize.title + 2, 16)
		Utils.create("ImageLabel", {
			Size = UDim2.new(0, premiumSize, 0, premiumSize),
			BackgroundTransparency = 1,
			Image = PREMIUM_ICON,
			ImageColor3 = playerColor,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 2,
			Parent = nameCont,
		})
	end

	if isAdmin then
		Utils.createLabel({ Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextColor3 = playerColor, TextSize = L.fontSize.title, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3, Parent = nameCont })
	end

	Utils.createLabel({ Size = UDim2.new(1, 0, 0, 16), Text = "@" .. data.username, TextColor3 = THEME.muted, TextSize = L.fontSize.subtitle + 3, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 2, Parent = nameMain })

	if isAdmin and badgeInfo then
		local badge = Admin.createBadge(avatarSection, badgeInfo, L)
		badge.Position = UDim2.new(0, 10, 1, nameY - 24); badge.ZIndex = 26
	end

	-- Like buttons
	if data.userId ~= player.UserId then
		local likeCont = Utils.createFrame({ Size = UDim2.new(0, L.likeButtonSize + 4, 0, (L.likeButtonSize * 2) + 8), Position = UDim2.new(0, 10, 0, 10), BackgroundTransparency = 1, ZIndex = 15, Parent = avatarSection })
		Utils.create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 6), Parent = likeCont })

		local function mkLikeBtn(imgId, onClick)
			local b = Utils.create("ImageButton", { Size = UDim2.new(0, L.likeButtonSize, 0, L.likeButtonSize), BackgroundColor3 = Color3.fromRGB(20, 20, 25), BackgroundTransparency = 0.3, Image = imgId, ScaleType = Enum.ScaleType.Fit, AutoButtonColor = false, ZIndex = 15, Parent = likeCont })
			Utils.addCorner(b, L.likeButtonSize / 2)
			Utils.addConnection(b.MouseButton1Click:Connect(onClick))
			Utils.addConnection(b.MouseEnter:Connect(function() safeTween(b, { ImageTransparency = 0.3, BackgroundTransparency = 0.1 }, Config.ANIM_FAST) end))
			Utils.addConnection(b.MouseLeave:Connect(function() safeTween(b, { ImageTransparency = 0, BackgroundTransparency = 0.3 }, Config.ANIM_FAST) end))
			return b
		end

		mkLikeBtn("rbxassetid://118393090095169", function()
			if State.target and State.userId ~= player.UserId then LikesSystem.giveLike(State.target) end
		end)
		mkLikeBtn("rbxassetid://9412108006", function()
			if State.target and State.userId ~= player.UserId then LikesSystem.giveSuperLike(State.target) end
		end)
	end

	return avatarSection
end

-- ═══════════════════════════════════════════════════════════════
-- CREAR PANEL COMPLETO
-- ═══════════════════════════════════════════════════════════════
function PanelView.createPanel(data)
	if State.closing or not data or not data.userId then return nil end

	local L = getLayout()

	local screenGui = Utils.createScreenGui(playerGui)

	State.container = Utils.createFrame({ Size = UDim2.new(0, L.panelWidth, 0, L.panelHeight), Position = UDim2.new(0.5, -L.panelWidth / 2, 1, 50), BackgroundTransparency = 1, Parent = screenGui })

	local target
	for _, p in ipairs(Services.Players:GetPlayers()) do
		if p.UserId == data.userId then target = p; break end
	end
	local playerColor = Utils.getPlayerColor(target, ColorEffects)
	State.playerColor = playerColor
	State.target = target

	-- Drag Handle
	local dragHandle = Utils.createFrame({ Size = UDim2.new(1, 0, 0, L.dragHandleH), Parent = State.container })
	Utils.addCorner(dragHandle, L.cornerRadius)

	local dragInd = Utils.createFrame({ Size = UDim2.new(0, 44, 0, 4), Position = UDim2.new(0.5, -22, 0.5, -2), BackgroundColor3 = playerColor, BackgroundTransparency = 0.25, Parent = dragHandle })
	Utils.addCorner(dragInd, 999)

	-- Drag logic
	local isDragging = false
	local dragStart, startPos

	Utils.addConnection(dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true; State.dragging = true
			dragStart = input.Position; startPos = State.container.Position
			local endConn
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isDragging = false; task.delay(0.15, function() State.dragging = false end); endConn:Disconnect()
				end
			end)
		end
	end))

	Utils.addConnection(Services.UserInputService.InputChanged:Connect(function(input)
		if not isDragging or not State.container or not State.container.Parent then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart
			State.container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))

	-- Panel container
	local pY = L.dragHandleH + 4
	local panelContainer = Utils.create("CanvasGroup", { Size = UDim2.new(1, 0, 0, L.panelHeight), Position = UDim2.new(0, 0, 0, pY), BackgroundColor3 = THEME.bg, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = State.container })
	Utils.addCorner(panelContainer, L.cornerRadius)

	local isUserAdmin = Admin.isAdmin(data.username)
	applyGlass(panelContainer, playerColor, L, isUserAdmin)

	local panelStroke = Utils.addStroke(panelContainer, THEME.stroke, 1.6, 0.25)
	State.panelStroke = panelStroke
	State.panelContainer = panelContainer

	-- Vignette lateral izquierdo (igual que MenuPanel)
	local edgeL = Utils.createFrame({ Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = THEME.bg, BackgroundTransparency = 0, ZIndex = 10, Parent = panelContainer })
	local gL = Instance.new("UIGradient")
	gL.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.6, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	gL.Parent = edgeL

	-- Vignette lateral derecho
	local edgeR = Utils.createFrame({ Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -30, 0, 0), BackgroundColor3 = THEME.bg, BackgroundTransparency = 0, ZIndex = 10, Parent = panelContainer })
	local gR = Instance.new("UIGradient")
	gR.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.85),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	gR.Parent = edgeR

	local panelImage = Utils.create("ImageLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "", ImageTransparency = 0.6, ScaleType = Enum.ScaleType.Crop, ZIndex = 1, Parent = panelContainer })
	State.panelBgImage = panelImage

	local panel = Utils.create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingEnabled = true,
		Active = true, ZIndex = 5, Parent = panelContainer
	})
	ModernScrollbar.setup(panel, panelContainer, THEME, { color = playerColor, offset = -6 })

	createAvatarSection(panel, data, playerColor)

	-- Likes listener
	if State.target then
		local lastLikes = State.target:GetAttribute("TotalLikes") or 0
		local animating = false

		Utils.addConnection(State.target:GetAttributeChangedSignal("TotalLikes"):Connect(function()
			local nl = State.target:GetAttribute("TotalLikes") or 0
			if nl == lastLikes then return end
			if State.statsLabels and State.statsLabels.likes and State.statsLabels.likes.Parent then
				State.statsLabels.likes.Text = tostring(nl)
				if nl > lastLikes and not animating then
					animating = true
					local orig = State.statsLabels.likes.TextSize
					local bump = (nl - lastLikes >= 10) and 6 or 4
					safeTween(State.statsLabels.likes, { TextSize = orig + bump }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					task.delay(0.2, function()
						if State.statsLabels.likes and State.statsLabels.likes.Parent then
							safeTween(State.statsLabels.likes, { TextSize = orig }, 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
							task.delay(0.2, function() animating = false end)
						else animating = false end
					end)
				end
			end
			lastLikes = nl
		end))

		if State.statsLabels and State.statsLabels.likes then
			State.statsLabels.likes.Text = tostring(lastLikes)
		end
	end

	createButtonsSection(panel, State.target, playerColor)

	-- Entrada animada
	State.container.Position = UDim2.new(0.5, -L.panelWidth / 2, 1, 50)
	task.defer(function()
		safeTween(State.container, { Position = UDim2.new(0.5, -L.panelWidth / 2, 1, -(L.panelHeight + L.bottomOffset)) }, 0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end)

	Utils.startAutoRefresh(State, Remotes)
	return screenGui
end

-- ═══════════════════════════════════════════════════════════════
-- VIP BACKGROUND (aplicado async tras verificar VIP en servidor)
-- ═══════════════════════════════════════════════════════════════
function PanelView.applyVipBackground(groupIcon, playerColor)
	local img = State.panelBgImage
	if not img or not img.Parent then return end
	if not groupIcon or groupIcon == "" then return end

	img.Image = groupIcon
	img.ScaleType = Enum.ScaleType.Crop
	img.ImageTransparency = 0.65
	img.BackgroundTransparency = 1

	-- Limpiar gradiente anterior si existe
	for _, child in ipairs(img:GetChildren()) do
		if child:IsA("UIGradient") then child:Destroy() end
	end

	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 0.65),
	})
	g.Parent = img

	-- Borde animado con color del jugador
	if State.panelStroke then
		Admin.applyBorderGradient(State.panelStroke, 1.5, playerColor or THEME.accent)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP
-- ═══════════════════════════════════════════════════════════════
function PanelView.cleanupTweens()
	for k, tw in pairs(activeTweens) do
		pcall(function() tw:Cancel() end)
		activeTweens[k] = nil
	end
	for _, conn in ipairs(adminRotationConns) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(adminRotationConns)
end

function PanelView.invalidateLayoutCache()
	cachedLayout = nil
	lastDeviceType = nil
end

return PanelView