--[[
	═══════════════════════════════════════════════════════════════════════════════
	   EMOTES SYSTEM 
	═══════════════════════════════════════════════════════════════════════════════
]]--

-- Autor: ignxts

-- ════════════════════════════════════════════════════════════════════════════════
-- CONFIGURACIÓN
-- ════════════════════════════════════════════════════════════════════════════════


local Config = {
	PC_Ancho = 240,
	PC_Alto = 470,
	PC_MargenIzquierdo = 5,
	PC_OffsetVertical = 120,

	Movil_Ancho = 190,
	Movil_Alto = 315,
	Movil_MargenIzquierdo = 5,
	Movil_OffsetVertical = 10,

	Movil_MostrarBusqueda = true,
}

-- ════════════════════════════════════════════════════════════════════════════════
-- SERVICIOS
-- ════════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ════════════════════════════════════════════════════════════════════════════════
-- REFERENCIAS
-- ════════════════════════════════════════════════════════════════════════════════

local Replicado = ReplicatedStorage:WaitForChild("RemotesGlobal")
local Remotos = Replicado:WaitForChild("Eventos_Emote")
local RemotesSync = Replicado:WaitForChild("Emotes_Sync")

local ObtenerFavs = Remotos:WaitForChild("ObtenerFavs")
local AnadirFav = Remotos:WaitForChild("AnadirFav")
local PlayAnimationRemote = RemotesSync:FindFirstChild("PlayAnimation")
local StopAnimationRemote = RemotesSync:FindFirstChild("StopAnimation")
local SyncRemote = RemotesSync:FindFirstChild("Sync")

-- Las funciones setActiveByName y clearActive se definen DESPUÉS de ScrollFrame

local THEME_CONFIG = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThemeConfig"))
local Modulo = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Animaciones"))
local NotificationSystem = require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("NotificationSystem"):WaitForChild("NotificationSystem"))
local ModernScrollbar = require(ReplicatedStorage:WaitForChild("UIComponents"):WaitForChild("ModernScrollbar"))
local SubTabs = require(ReplicatedStorage:WaitForChild("UIComponents"):WaitForChild("SubTabs"))

-- ════════════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ════════════════════════════════════════════════════════════════════════════════

local Jugador = Players.LocalPlayer
local PlayerGui = Jugador:WaitForChild("PlayerGui")

local IsMobile = UserInputService.TouchEnabled
local EmotesFavs = {}
local DanceActivated = nil
local ActiveCard = nil
local TabActual = "POSES"
local IsSynced = false -- Estado de sincronización
local currentLeaderUserId = nil -- UserId del jugador que sigo (nil si no sigo a nadie)

-- Gestión de memoria
local CardConnections = {}
local ActiveTweens = {}
local GlobalConnections = {}

-- ════════════════════════════════════════════════════════════════════════════════
-- UTILIDADES
-- ════════════════════════════════════════════════════════════════════════════════

local function Tween(obj, dur, props, style, direction)
	if not obj or not obj.Parent then return nil end
	local tween = TweenService:Create(
		obj, 
		TweenInfo.new(dur, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), 
		props
	)
	tween:Play()
	return tween
end

local function CreateCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function CreateStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME_CONFIG.stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function GetCardHeight()
	return IsMobile and 38 or 46
end

local function EncontrarDatos(BaileId)
	for _, v in ipairs(Modulo.Lista) do
		if v.ID == BaileId then return v.Nombre end
	end
	return "Dance"
end

local function EstaEnFavoritos(id)
	return table.find(EmotesFavs, id) ~= nil
end

-- ════════════════════════════════════════════════════════════════════════════════
-- GESTIÓN DE MEMORIA MEJORADA
-- ════════════════════════════════════════════════════════════════════════════════

local function TrackConnection(card, connection)
	if not card then return end
	if not CardConnections[card] then
		CardConnections[card] = {}
	end
	table.insert(CardConnections[card], connection)
end

local function TrackGlobalConnection(connection)
	table.insert(GlobalConnections, connection)
end

local function TrackTween(card, tween)
	if not card or not tween then return end
	if not ActiveTweens[card] then
		ActiveTweens[card] = {}
	end
	table.insert(ActiveTweens[card], tween)
end

local function CleanupCard(card)
	if not card then return end

	-- Cancelar tweens activos
	if ActiveTweens[card] then
		for _, tween in ipairs(ActiveTweens[card]) do
			if tween then
				pcall(function() tween:Cancel() end)
			end
		end
		ActiveTweens[card] = nil
	end

	-- Desconectar eventos
	if CardConnections[card] then
		for _, conn in ipairs(CardConnections[card]) do
			if conn then
				pcall(function() conn:Disconnect() end)
			end
		end
		CardConnections[card] = nil
	end
end

local function CleanupAllCards()
	for card in pairs(CardConnections) do
		CleanupCard(card)
	end
	for card in pairs(ActiveTweens) do
		if ActiveTweens[card] then
			for _, tween in ipairs(ActiveTweens[card]) do
				if tween then pcall(function() tween:Cancel() end) end
			end
		end
	end
	CardConnections = {}
	ActiveTweens = {}
end

-- ════════════════════════════════════════════════════════════════════════════════
-- ANIMACIÓN ACTIVA
-- ════════════════════════════════════════════════════════════════════════════════

local function AplicarEfectoActivo(card)
	if not card or not card.Parent then return end

	local border = card:FindFirstChild("ActiveBorder")
	local overlay = card:FindFirstChild("ActiveOverlay")

	if border then
		TrackTween(card, Tween(border, 0.12, {Transparency = 0, Thickness = 2}, Enum.EasingStyle.Quad))
	end

	if overlay then
		TrackTween(card, Tween(overlay, 0.12, {BackgroundTransparency = 0.8}, Enum.EasingStyle.Quad))
	end
end

local function RemoverEfectoActivo(card)
	if not card or not card.Parent then return end

	local border = card:FindFirstChild("ActiveBorder")
	local overlay = card:FindFirstChild("ActiveOverlay")

	if border then
		TrackTween(card, Tween(border, 0.08, {Transparency = 1, Thickness = 2}, Enum.EasingStyle.Quad))
	end

	if overlay then
		TrackTween(card, Tween(overlay, 0.08, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad))
	end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- GUI PRINCIPAL
-- ════════════════════════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EmotesModernUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel = 0
MainFrame.Visible = true
MainFrame.AnchorPoint = Vector2.new(0, 0.5)
MainFrame.ClipsDescendants = false
MainFrame.Parent = ScreenGui

local emotesPanelOpen = false

local function ActualizarTamanoFrame()
	if IsMobile then
		MainFrame.Size = UDim2.new(0, Config.Movil_Ancho, 0, Config.Movil_Alto)
		MainFrame.Position = UDim2.new(0, -Config.Movil_Ancho, 0.5, Config.Movil_OffsetVertical)
	else
		MainFrame.Size = UDim2.new(0, Config.PC_Ancho, 0, Config.PC_Alto)
		MainFrame.Position = UDim2.new(0, -Config.PC_Ancho, 0.5, Config.PC_OffsetVertical)
	end
end
ActualizarTamanoFrame()

-- CanvasGroup para clipear bordes redondeados correctamente
local ContentCanvas = Instance.new("CanvasGroup")
ContentCanvas.Name = "ContentCanvas"
ContentCanvas.Size = UDim2.new(1, 0, 1, 0)
ContentCanvas.BackgroundColor3 = THEME_CONFIG.bg
ContentCanvas.BackgroundTransparency = 0
ContentCanvas.BorderSizePixel = 0
ContentCanvas.Parent = MainFrame
CreateCorner(ContentCanvas, 12)
CreateStroke(ContentCanvas, THEME_CONFIG.stroke, 1, 0.5)

-- ════════════════════════════════════════════════════════════════════════════════
-- BOTÓN TOGGLE (pegado al borde derecho del panel)
-- ════════════════════════════════════════════════════════════════════════════════

local btnSize = IsMobile and 40 or 45

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Name = "EmoteToggle"
ToggleBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
ToggleBtn.Position = UDim2.new(1, 4, 0.5, 0)
ToggleBtn.AnchorPoint = Vector2.new(0, 0.5)
ToggleBtn.BackgroundColor3 = THEME_CONFIG.bg
ToggleBtn.BackgroundTransparency = 0
ToggleBtn.Image = ""
ToggleBtn.AutoButtonColor = false
ToggleBtn.ZIndex = 10
ToggleBtn.Parent = MainFrame
CreateCorner(ToggleBtn, btnSize / 2)
CreateStroke(ToggleBtn, THEME_CONFIG.stroke, 1, 0.5)

local ToggleIcon = Instance.new("ImageLabel")
ToggleIcon.Name = "Icon"
ToggleIcon.Image = "rbxassetid://88883622923552"
ToggleIcon.ImageColor3 = THEME_CONFIG.text
ToggleIcon.BackgroundTransparency = 1
ToggleIcon.Size = UDim2.new(1, -12, 1, -12)
ToggleIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
ToggleIcon.AnchorPoint = Vector2.new(0.5, 0.5)
ToggleIcon.ScaleType = Enum.ScaleType.Fit
ToggleIcon.ZIndex = 11
ToggleIcon.Parent = ToggleBtn

ToggleBtn.MouseEnter:Connect(function()
	Tween(ToggleBtn, 0.07, {BackgroundColor3 = THEME_CONFIG.elevated}, Enum.EasingStyle.Quad)
end)
ToggleBtn.MouseLeave:Connect(function()
	Tween(ToggleBtn, 0.07, {BackgroundColor3 = THEME_CONFIG.bg}, Enum.EasingStyle.Quad)
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- TABS (SubTabs con Blob Indicator)
-- ════════════════════════════════════════════════════════════════════════════════

local tabHeight = IsMobile and 38 or 46

local subTabs = SubTabs.new(ContentCanvas, THEME_CONFIG, {
	tabs = {
		{ id = "POSES",     label = "POSES"     },
		{ id = "DANCES",    label = "DANCES"    },
		{ id = "FAVORITOS", label = "FAVS" },
	},
	height = tabHeight,
	default = "POSES",
	textSize = IsMobile and 13 or 15,
})

local posY = tabHeight
local sliderHeight = IsMobile and 52 or 62

-- ════════════════════════════════════════════════════════════════════════════════
-- BÚSQUEDA (ARREGLADA - sin desbordamiento de texto)
-- ════════════════════════════════════════════════════════════════════════════════

local mostrarBusqueda = IsMobile and Config.Movil_MostrarBusqueda or true
local SearchContainer, SearchBox

if mostrarBusqueda then
	SearchContainer = Instance.new("Frame")
	SearchContainer.Name = "SearchContainer"
	SearchContainer.Size = UDim2.new(1, 0, 0, IsMobile and 32 or 40)
	SearchContainer.Position = UDim2.new(0, 0, 0, posY)
	SearchContainer.BackgroundTransparency = 1
	SearchContainer.BorderSizePixel = 0
	SearchContainer.ClipsDescendants = true
	SearchContainer.Parent = ContentCanvas

	-- Icono de lupa moderno (círculo + línea)
	local SearchIconContainer = Instance.new("Frame")
	SearchIconContainer.Name = "SearchIconContainer"
	SearchIconContainer.Size = UDim2.new(0, IsMobile and 20 or 26, 1, 0)
	SearchIconContainer.Position = UDim2.new(0, IsMobile and 4 or 6, 0, 0)
	SearchIconContainer.BackgroundTransparency = 1
	SearchIconContainer.Parent = SearchContainer

	-- Círculo de la lupa
	local SearchCircle = Instance.new("Frame")
	SearchCircle.Name = "SearchCircle"
	SearchCircle.Size = UDim2.new(0, IsMobile and 10 or 12, 0, IsMobile and 10 or 12)
	SearchCircle.Position = UDim2.new(0.5, IsMobile and -6 or -7, 0.5, IsMobile and -6 or -7)
	SearchCircle.BackgroundTransparency = 1
	SearchCircle.Parent = SearchIconContainer
	CreateCorner(SearchCircle, 100)
	local circleStroke = CreateStroke(SearchCircle, THEME_CONFIG.subtle, IsMobile and 1.5 or 2, 0.3)

	-- Línea diagonal de la lupa
	local SearchHandle = Instance.new("Frame")
	SearchHandle.Name = "SearchHandle"
	SearchHandle.Size = UDim2.new(0, IsMobile and 5 or 6, 0, IsMobile and 1.5 or 2)
	SearchHandle.Position = UDim2.new(0.5, IsMobile and 2 or 3, 0.5, IsMobile and 3 or 4)
	SearchHandle.Rotation = 45
	SearchHandle.BackgroundColor3 = THEME_CONFIG.subtle
	SearchHandle.BackgroundTransparency = THEME_CONFIG.lightAlpha
	SearchHandle.BorderSizePixel = 0
	SearchHandle.Parent = SearchIconContainer
	CreateCorner(SearchHandle, 2)

	SearchBox = Instance.new("TextBox")
	SearchBox.Name = "SearchBox"
	SearchBox.Size = UDim2.new(1, IsMobile and -28 or -36, 1, 0)
	SearchBox.Position = UDim2.new(0, IsMobile and 24 or 30, 0, 0)
	SearchBox.BackgroundTransparency = 1
	SearchBox.Font = Enum.Font.GothamMedium
	SearchBox.PlaceholderText = "Buscar baile..."
	SearchBox.PlaceholderColor3 = THEME_CONFIG.subtle
	SearchBox.Text = ""
	SearchBox.TextColor3 = THEME_CONFIG.text
	SearchBox.TextSize = IsMobile and 13 or 15
	SearchBox.TextXAlignment = Enum.TextXAlignment.Left
	SearchBox.TextTruncate = Enum.TextTruncate.AtEnd
	SearchBox.ClearTextOnFocus = false
	SearchBox.ClipsDescendants = true
	SearchBox.Parent = SearchContainer

	-- Animación al enfocar
	TrackGlobalConnection(SearchBox.Focused:Connect(function()
		Tween(circleStroke, 0.2, {Color = THEME_CONFIG.accent, Transparency = 0})
		Tween(SearchHandle, 0.2, {BackgroundColor3 = THEME_CONFIG.accent, BackgroundTransparency = 0})
	end))

	TrackGlobalConnection(SearchBox.FocusLost:Connect(function()
		Tween(circleStroke, 0.2, {Color = THEME_CONFIG.subtle, Transparency = THEME_CONFIG.lightAlpha})
		Tween(SearchHandle, 0.2, {BackgroundColor3 = THEME_CONFIG.subtle, BackgroundTransparency = THEME_CONFIG.lightAlpha})
	end))

	posY = posY + (IsMobile and 32 or 40)
end



-- ════════════════════════════════════════════════════════════════════════════════
-- CONTENEDOR DE SCROLL
-- ════════════════════════════════════════════════════════════════════════════════

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, 0, 1, -(posY + sliderHeight))
ContentArea.Position = UDim2.new(0, 0, 0, posY)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = false
ContentArea.Parent = ContentCanvas

-- ════════════════════════════════════════════════════════════════════════════════
-- OVERLAY DE SINCRONIZACIÓN MODERNO
-- ════════════════════════════════════════════════════════════════════════════════

local SyncOverlay = Instance.new("TextButton")
SyncOverlay.Name = "SyncOverlay"
SyncOverlay.Size = UDim2.new(1, 0, 1, 0)
SyncOverlay.Position = UDim2.new(0, 0, 0, 0)
SyncOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SyncOverlay.BackgroundTransparency = THEME_CONFIG.lightAlpha
SyncOverlay.BorderSizePixel = 0
SyncOverlay.Text = ""
SyncOverlay.AutoButtonColor = false
SyncOverlay.ZIndex = 100
SyncOverlay.Visible = false
SyncOverlay.Parent = ContentArea
CreateCorner(SyncOverlay, IsMobile and 8 or 12)

-- Nombre del jugador directo en el overlay
local SyncPlayerName = Instance.new("TextLabel")
SyncPlayerName.Name = "SyncPlayerName"
SyncPlayerName.Size = UDim2.new(1, -20, 0, IsMobile and 30 or 36)
SyncPlayerName.Position = UDim2.new(0, 10, 0.5, IsMobile and -22 or -26)
SyncPlayerName.BackgroundTransparency = 1
SyncPlayerName.Font = Enum.Font.GothamBold
SyncPlayerName.Text = "Player Name"
SyncPlayerName.TextColor3 = THEME_CONFIG.accent
SyncPlayerName.TextSize = IsMobile and 20 or 24
SyncPlayerName.TextTruncate = Enum.TextTruncate.AtEnd
SyncPlayerName.TextXAlignment = Enum.TextXAlignment.Center
SyncPlayerName.ZIndex = 101
SyncPlayerName.Parent = SyncOverlay

local SyncHint = Instance.new("TextLabel")
SyncHint.Name = "SyncHint"
SyncHint.Size = UDim2.new(1, -20, 0, IsMobile and 14 or 16)
SyncHint.Position = UDim2.new(0, 10, 0.5, IsMobile and 10 or 12)
SyncHint.BackgroundTransparency = 1
SyncHint.Font = Enum.Font.GothamBold
SyncHint.Text = "Toca para desincronizarte"
SyncHint.TextColor3 = THEME_CONFIG.subtle
SyncHint.TextSize = IsMobile and 12 or 14
SyncHint.TextXAlignment = Enum.TextXAlignment.Center
SyncHint.ZIndex = 101
SyncHint.Parent = SyncOverlay

-- Función para mostrar/ocultar el overlay
local function SetSyncOverlay(synced, syncedPlayerName)
	IsSynced = synced
	if synced then
		SyncPlayerName.Text = syncedPlayerName or "Desconocido"
		SyncOverlay.BackgroundTransparency = 1
		SyncOverlay.Visible = true
		Tween(SyncOverlay, 0.3, {BackgroundTransparency = THEME_CONFIG.lightAlpha})
	else
		local t = Tween(SyncOverlay, 0.3, {BackgroundTransparency = 1})
		if t then
			t.Completed:Connect(function()
				SyncOverlay.Visible = false
			end)
		end
	end
end

-- Click en el overlay para desincronizarse
SyncOverlay.MouseButton1Click:Connect(function()
	if SyncRemote then
		SyncRemote:FireServer("unsync")
		SetSyncOverlay(false)
		NotificationSystem:Info("Sync", "Te has desincronizado", 2)
	end
end)

-- Hover en el overlay
SyncOverlay.MouseEnter:Connect(function()
	Tween(SyncPlayerName, 0.15, {TextColor3 = Color3.fromRGB(255, 255, 255)})
end)

SyncOverlay.MouseLeave:Connect(function()
	Tween(SyncPlayerName, 0.15, {TextColor3 = THEME_CONFIG.accent})
end)

-- Nota: el cliente ya no usa valores en el Character; escucha `SyncUpdate` desde el servidor

-- ════════════════════════════════════════════════════════════════════════════════
-- SCROLL FRAMES (uno por pestaña — evita recrear listas fijas al cambiar tab)
-- ════════════════════════════════════════════════════════════════════════════════

local function CrearScrollFrame(nombre)
	local sf = Instance.new("ScrollingFrame")
	sf.Name = nombre
	sf.Size = UDim2.new(1, 0, 1, 0)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 0
	sf.ScrollBarImageTransparency = 1
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.Parent = ContentArea

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, IsMobile and 3 or 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = sf

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, IsMobile and 2 or 4)
	pad.PaddingBottom = UDim.new(0, IsMobile and 4 or 10)
	pad.PaddingLeft = UDim.new(0, IsMobile and 4 or 6)
	pad.PaddingRight = UDim.new(0, IsMobile and 4 or 6)
	pad.Parent = sf

	local emptyMsg = Instance.new("TextLabel")
	emptyMsg.Name = "EmptyMessage"
	emptyMsg.Size = UDim2.new(0, 0, 0, 0)
	emptyMsg.BackgroundTransparency = 1
	emptyMsg.Font = Enum.Font.GothamMedium
	emptyMsg.Text = "Sin favoritos\nToca el ícono en cualquier baile"
	emptyMsg.TextColor3 = THEME_CONFIG.subtle
	emptyMsg.TextSize = IsMobile and 13 or 15
	emptyMsg.Visible = false
	emptyMsg.LayoutOrder = 999
	emptyMsg.Parent = sf

	ModernScrollbar.setup(sf, ContentArea, THEME_CONFIG, { color = THEME_CONFIG.accent, offset = -6, transparency = 0 })

	return sf, emptyMsg
end

local ScrollPoses,  EmptyPoses  = CrearScrollFrame("ScrollPoses")
local ScrollDances, EmptyDances = CrearScrollFrame("ScrollDances")
local ScrollFavs,   EmptyFavs   = CrearScrollFrame("ScrollFavs")

-- Ocultar tabs inactivos al inicio (ModernScrollbar sincroniza su mirror automáticamente)
ScrollDances.Visible = false
ScrollFavs.Visible   = false

local ActiveScroll = ScrollPoses
local ActiveEmpty  = EmptyPoses

local function ShowTab(newTabId)
	-- Ocultar pestaña actual
	local sfMap = { POSES = ScrollPoses, DANCES = ScrollDances, FAVORITOS = ScrollFavs }
	local emMap = { POSES = EmptyPoses,  DANCES = EmptyDances,  FAVORITOS = EmptyFavs  }
	if sfMap[TabActual] then sfMap[TabActual].Visible = false end
	-- Mostrar nueva
	local sf = sfMap[newTabId]
	if sf then
		sf.Visible  = true
		ActiveScroll = sf
		ActiveEmpty  = emMap[newTabId]
	end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- SLIDER DE VELOCIDAD
-- ════════════════════════════════════════════════════════════════════════════════

-- Rango simétrico alrededor de 1.0 → 1.0 siempre queda en el centro del slider
-- MIN + MAX = 2.0 garantiza que fraction(1.0) = 0.5 (centro exacto)
local MIN_SPEED      = 0.1
local MAX_SPEED      = 1.9
local currentSpeed   = 1.0
local isDraggingSlider = false

-- ════════════════════════════════════════════════════════════════════════════════
-- BOTÓN STOP (encima del slider, visible solo con baile activo)
-- ════════════════════════════════════════════════════════════════════════════════

local stopBtnHeight = IsMobile and 26 or 30

local StopButton = Instance.new("TextButton")
StopButton.Name = "StopButton"
StopButton.Size = UDim2.new(1, 0, 0, stopBtnHeight)
StopButton.Position = UDim2.new(0, 0, 1, -(sliderHeight + stopBtnHeight))
StopButton.BackgroundColor3 = THEME_CONFIG.card
StopButton.BackgroundTransparency = 0
StopButton.BorderSizePixel = 0
StopButton.Text = "STOP"
StopButton.Font = Enum.Font.GothamBold
StopButton.TextSize = IsMobile and 14 or 16
StopButton.TextColor3 = THEME_CONFIG.accent
StopButton.AutoButtonColor = false
StopButton.ZIndex = 5
StopButton.Visible = false
StopButton.Parent = ContentCanvas

local stopDivider = Instance.new("Frame")
stopDivider.Name = "StopDivider"
stopDivider.Size = UDim2.new(1, 0, 0, 1)
stopDivider.Position = UDim2.new(0, 0, 0, 0)
stopDivider.BackgroundColor3 = THEME_CONFIG.stroke
stopDivider.BackgroundTransparency = 0.4
stopDivider.BorderSizePixel = 0
stopDivider.ZIndex = 5
stopDivider.Parent = StopButton

StopButton.MouseEnter:Connect(function()
	Tween(StopButton, 0.07, {BackgroundColor3 = THEME_CONFIG.elevated, TextColor3 = THEME_CONFIG.text}, Enum.EasingStyle.Quad)
end)
StopButton.MouseLeave:Connect(function()
	Tween(StopButton, 0.07, {BackgroundColor3 = THEME_CONFIG.card, TextColor3 = THEME_CONFIG.accent}, Enum.EasingStyle.Quad)
end)

local function ShowStopButton(show)
	StopButton.Visible = show
	-- Ajustar ContentArea para dar espacio al botón stop
	local extra = show and stopBtnHeight or 0
	ContentArea.Size = UDim2.new(1, 0, 1, -(posY + sliderHeight + extra))
end

local SpeedContainer = Instance.new("Frame")
SpeedContainer.Name = "SpeedContainer"
SpeedContainer.Size = UDim2.new(1, 0, 0, sliderHeight)
SpeedContainer.Position = UDim2.new(0, 0, 1, -sliderHeight)
SpeedContainer.BackgroundColor3 = THEME_CONFIG.card
SpeedContainer.BackgroundTransparency = 0
SpeedContainer.BorderSizePixel = 0
SpeedContainer.ZIndex = 5
SpeedContainer.Parent = ContentCanvas

local SpeedDivider = Instance.new("Frame")
SpeedDivider.Name = "SpeedDivider"
SpeedDivider.Size = UDim2.new(1, 0, 0, 1)
SpeedDivider.BackgroundColor3 = THEME_CONFIG.stroke
SpeedDivider.BackgroundTransparency = 0.4
SpeedDivider.BorderSizePixel = 0
SpeedDivider.Parent = SpeedContainer

local sliderPad       = IsMobile and 10 or 14
local sliderTrackH    = IsMobile and 10 or 12
local sliderThumbSize = IsMobile and 24 or 28
local sliderTrackY    = math.floor((sliderHeight - sliderTrackH) / 2)

local SliderTrack = Instance.new("Frame")
SliderTrack.Name = "SliderTrack"
SliderTrack.Size = UDim2.new(1, -sliderPad * 2, 0, sliderTrackH)
SliderTrack.Position = UDim2.new(0, sliderPad, 0, sliderTrackY)
SliderTrack.BackgroundColor3 = THEME_CONFIG.elevated
SliderTrack.BackgroundTransparency = 0
SliderTrack.BorderSizePixel = 0
SliderTrack.ZIndex = 6
SliderTrack.ClipsDescendants = false
SliderTrack.Parent = SpeedContainer
CreateCorner(SliderTrack, 3)

local defaultFraction = (1.0 - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)

local SliderFill = Instance.new("Frame")
SliderFill.Name = "SliderFill"
SliderFill.Size = UDim2.new(defaultFraction, 0, 1, 0)
SliderFill.BackgroundColor3 = THEME_CONFIG.accent
SliderFill.BorderSizePixel = 0
SliderFill.ZIndex = 7
SliderFill.Parent = SliderTrack
CreateCorner(SliderFill, 3)

local SliderThumb = Instance.new("Frame")
SliderThumb.Name = "SliderThumb"
SliderThumb.Size = UDim2.new(0, sliderThumbSize, 0, sliderThumbSize)
SliderThumb.AnchorPoint = Vector2.new(0.5, 0.5)
SliderThumb.Position = UDim2.new(defaultFraction, 0, 0.5, 0)
SliderThumb.BackgroundColor3 = THEME_CONFIG.accent
SliderThumb.BorderSizePixel = 0
SliderThumb.ZIndex = 8
SliderThumb.Parent = SliderTrack
CreateCorner(SliderThumb, sliderThumbSize / 2)
CreateStroke(SliderThumb, THEME_CONFIG.bg, 2, 0)

-- Botón invisible sobre todo el slider para captura fiable de input (como MusicSystem)
local SliderHitArea = Instance.new("TextButton")
SliderHitArea.Name = "SliderHitArea"
SliderHitArea.Size = UDim2.new(1, 0, 1, 0)
SliderHitArea.BackgroundTransparency = 1
SliderHitArea.Text = ""
SliderHitArea.AutoButtonColor = false
SliderHitArea.ZIndex = 9
SliderHitArea.Parent = SpeedContainer

local function UpdateSliderUI(speed, animate)
	speed = math.clamp(speed, MIN_SPEED, MAX_SPEED)
	local fraction = (speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
	if animate == false or isDraggingSlider then
		SliderFill.Size = UDim2.new(fraction, 0, 1, 0)
		SliderThumb.Position = UDim2.new(fraction, 0, 0.5, 0)
	else
		Tween(SliderFill, 0.12, {Size = UDim2.new(fraction, 0, 1, 0)}, Enum.EasingStyle.Quad)
		Tween(SliderThumb, 0.12, {Position = UDim2.new(fraction, 0, 0.5, 0)}, Enum.EasingStyle.Quad)
	end
end

local function GetSliderFraction(inputX)
	local absPos = SliderTrack.AbsolutePosition
	local absSize = SliderTrack.AbsoluteSize
	if absSize.X <= 0 then return 0 end
	return math.clamp((inputX - absPos.X) / absSize.X, 0, 1)
end

local speedServerDebounce = nil
local activeDragInput = nil -- Rastrear el input exacto que inició el drag

local function ApplySpeed(rawFraction)
	if IsSynced then return end
	local speed = MIN_SPEED + rawFraction * (MAX_SPEED - MIN_SPEED)
	currentSpeed = math.clamp(speed, MIN_SPEED, MAX_SPEED)
	UpdateSliderUI(currentSpeed)
	if DanceActivated and PlayAnimationRemote then
		if speedServerDebounce then task.cancel(speedServerDebounce) end
		speedServerDebounce = task.delay(0.05, function()
			local rounded = math.round(currentSpeed * 10) / 10
			PlayAnimationRemote:FireServer("setSpeed", rounded)
			speedServerDebounce = nil
		end)
	end
end

local function StopSliderDrag()
	isDraggingSlider = false
	activeDragInput = nil
end

TrackGlobalConnection(SliderHitArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		isDraggingSlider = true
		activeDragInput = input
		ApplySpeed(GetSliderFraction(input.Position.X))
	end
end))

TrackGlobalConnection(UserInputService.InputChanged:Connect(function(input)
	if not isDraggingSlider then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		ApplySpeed(GetSliderFraction(input.Position.X))
	end
end))

TrackGlobalConnection(UserInputService.InputEnded:Connect(function(input)
	if not isDraggingSlider then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		StopSliderDrag()
	end
end))

-- ════════════════════════════════════════════════════════════════════════════════
-- HELPERS PARA SINCRONIZAR UI (optimizado con caché y debouncing)
-- ════════════════════════════════════════════════════════════════════════════════

local CardCache = {} -- Caché: nombre -> card reference
local lastActiveUpdate = 0
local activeUpdateDebounce = 0.1 -- 100ms debounce

-- Filtro activo por pestaña: nil = no cargado aún, string = filtro aplicado
local PosesFilter  = nil
local DancesFilter = nil

-- Actualizar caché: ActiveScroll tiene prioridad para resolver duplicados entre tabs
local function UpdateCardCache()
	CardCache = {}
	for _, child in ipairs(ActiveScroll:GetChildren()) do
		local cardName = child:GetAttribute("Name")
		if cardName then CardCache[cardName] = child end
	end
	for _, sf in ipairs({ScrollPoses, ScrollDances, ScrollFavs}) do
		if sf ~= ActiveScroll then
			for _, child in ipairs(sf:GetChildren()) do
				local cardName = child:GetAttribute("Name")
				if cardName and not CardCache[cardName] then
					CardCache[cardName] = child
				end
			end
		end
	end
end

local function setActiveByName(nombre)
	if not nombre then return end

	-- Debouncing: evitar actualizaciones muy frecuentes
	local now = tick()
	if now - lastActiveUpdate < activeUpdateDebounce then
		DanceActivated = nombre
		return
	end
	lastActiveUpdate = now

	-- Usar caché primero (muy rápido)
	local card = CardCache[nombre]

	-- Si no está en caché, buscar en todos los frames (activo primero)
	if not card then
		for _, sf in ipairs({ActiveScroll, ScrollPoses, ScrollDances, ScrollFavs}) do
			for _, child in ipairs(sf:GetChildren()) do
				if child:GetAttribute("Name") == nombre then
					card = child
					CardCache[nombre] = card
					break
				end
			end
			if card then break end
		end
	end

	-- Aplicar efecto si encontró la tarjeta
	if card and card.Parent then
		if ActiveCard and ActiveCard.Parent and ActiveCard ~= card then
			RemoverEfectoActivo(ActiveCard)
		end
		ActiveCard = card
		DanceActivated = nombre
		AplicarEfectoActivo(card)
		if StopButton then ShowStopButton(true) end
	else
		-- Guardar nombre para cuando se carguen las tarjetas
		DanceActivated = nombre
		if StopButton then ShowStopButton(true) end
	end
end

local function clearActive()
	if ActiveCard and ActiveCard.Parent then
		RemoverEfectoActivo(ActiveCard)
	end
	ActiveCard = nil
	DanceActivated = nil
	if StopButton then
		ShowStopButton(false)
	end
end

-- Escuchar eventos del servidor (con debouncing integrado)
if PlayAnimationRemote and PlayAnimationRemote.IsA and PlayAnimationRemote:IsA("RemoteEvent") then
	TrackGlobalConnection(PlayAnimationRemote.OnClientEvent:Connect(function(action, payload)
		if action == "playAnim" and type(payload) == "string" then
			setActiveByName(payload)
		end
	end))
end

if StopAnimationRemote and StopAnimationRemote.IsA and StopAnimationRemote:IsA("RemoteEvent") then
	TrackGlobalConnection(StopAnimationRemote.OnClientEvent:Connect(function()
		clearActive()
	end))
end

-- Escuchar actualizaciones de sincronización desde el servidor
local SyncUpdate = RemotesSync:FindFirstChild("SyncUpdate")
if SyncUpdate and SyncUpdate.IsA and SyncUpdate:IsA("RemoteEvent") then
	TrackGlobalConnection(SyncUpdate.OnClientEvent:Connect(function(payload)
		if not payload then return end

		--  NOTIFICACIÓN DE SEGUIDORES
		if payload.followerNotification and payload.followerNames then
			local message = ""
			if #payload.followerNames == 1 then
				message = payload.followerNames[1] .. " te está siguiendo"
			else
				message = #payload.followerNames .. " personas te siguen"
			end

			-- Mostrar notificación usando el método correcto
			if NotificationSystem then
				pcall(function()
					NotificationSystem:Info("Seguidores", message, 4)
				end)
			end
			return -- No procesar más si es una notificación
		end

		-- Mostrar/ocultar overlay de sync
		if payload.isSynced ~= nil then
			SetSyncOverlay(payload.isSynced, payload.leaderName)
		end

		-- Mostrar error de sincronización si existe
		if payload.syncError then
			pcall(function()
				NotificationSystem:Info("Sync Error", payload.syncError, 3)
			end)
		end

		-- Mantener UserId del líder que sigo (nil si ya no sigo a nadie)
		if payload.leaderUserId ~= nil then
			currentLeaderUserId = payload.leaderUserId
		else
			if payload.isSynced == false then
				currentLeaderUserId = nil
			end
		end

		-- Sincronizar animación activa en UI
		if payload.animationName and type(payload.animationName) == "string" and payload.animationName ~= "" then
			setActiveByName(payload.animationName)
		elseif payload.animationName == nil then
			-- si el servidor indica nil, limpiar activo
			clearActive()
		end
		-- Actualizar slider de velocidad desde servidor solo si estoy siguiendo a alguien
		-- (si soy dance leader, la velocidad es puramente local)
		if payload.speed ~= nil and IsSynced then
			currentSpeed = math.clamp(payload.speed, MIN_SPEED, MAX_SPEED)
			UpdateSliderUI(currentSpeed, false)
		end
	end))
end

-- Escuchar broadcasts de líderes (debounced desde servidor). Aplicar solo si el broadcast
-- corresponde al líder que este cliente está siguiendo (filtrado por UserId).
local SyncBroadcast = RemotesSync:FindFirstChild("SyncBroadcast")
if SyncBroadcast and SyncBroadcast.IsA and SyncBroadcast:IsA("RemoteEvent") then
	TrackGlobalConnection(SyncBroadcast.OnClientEvent:Connect(function(payload)
		if not payload then return end
		if not payload.leaderUserId then return end

		-- Solo aplicar si el broadcast es del líder que seguimos actualmente
		if currentLeaderUserId and payload.leaderUserId == currentLeaderUserId then
			if payload.animationName ~= nil then
				if payload.animationName == "" then
					clearActive()
				else
					setActiveByName(payload.animationName)
				end
			end
			-- Actualizar slider del seguidor con la velocidad del líder
			if payload.speed ~= nil then
				currentSpeed = math.clamp(payload.speed, MIN_SPEED, MAX_SPEED)
				UpdateSliderUI(currentSpeed, false)
			end
		end
	end))
end

-- Click en botón STOP
StopButton.MouseButton1Click:Connect(function()
	if DanceActivated then
		StopAnimationRemote:FireServer()
		clearActive()
	end
end)

local function MostrarEmptyMessage(mostrar, texto)
	if not ActiveEmpty then return end
	if texto then ActiveEmpty.Text = texto end
	ActiveEmpty.Visible = mostrar
	ActiveEmpty.Size = mostrar and UDim2.new(1, 0, 0, 60) or UDim2.new(0, 0, 0, 0)
end

-- Iconos de favorito (constantes)
local FAV_ICON   = "rbxassetid://75212439359134"
local NOFAV_ICON = "rbxassetid://72553305447429"

-- Lock global por ID (evita doble click en cards del mismo baile en distintas tabs)
local FavLocks = {}

-- Aplica estado de favorito al botón
local function ApplyFavBtnState(btn, isFav)
	if not btn then return end
	btn.Image = isFav and FAV_ICON or NOFAV_ICON
	btn.ImageColor3 = THEME_CONFIG.accent
	btn.ImageTransparency = isFav and 0 or THEME_CONFIG.lightAlpha
end

-- Sincroniza el icono de favorito en TODOS los frames para un ID dado
local function SyncFavAcrossTabs(id, isFav)
	for _, sf in ipairs({ScrollPoses, ScrollDances, ScrollFavs}) do
		for _, child in ipairs(sf:GetChildren()) do
			if child:GetAttribute("ID") == id then
				child:SetAttribute("IsFavorite", isFav)
				local fc = child:FindFirstChild("FavContainer")
				ApplyFavBtnState(fc and fc:FindFirstChild("FavBtn"), isFav)
			end
		end
	end
end

-- Anima la card de FAVORITOS y la destruye (al quitar fav)
local function ShrinkAndDestroy(card)
	if not (card and card.Parent) then return end
	CleanupCard(card)
	Tween(card, 0.2, {BackgroundTransparency = 0.8})
	local shrink = Tween(card, 0.2, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if shrink then
		shrink.Completed:Connect(function()
			if card and card.Parent then card:Destroy() end
		end)
	elseif card and card.Parent then
		card:Destroy()
	end
end

-- Destruye TODAS las cards con un ID dado en un scroll
local function RemoveCardFromScroll(sf, id, animate)
	for _, child in ipairs(sf:GetChildren()) do
		if child:GetAttribute("ID") == id and child:GetAttribute("Entry") then
			if child == ActiveCard then ActiveCard = nil end
			if animate then
				ShrinkAndDestroy(child)
			else
				CleanupCard(child)
				child:Destroy()
			end
		end
	end
end

-- Toggle de favorito: estado optimista + servidor + reconciliación
local function ToggleFavorite(id, nombre, sourceCard)
	if FavLocks[id] then return end
	FavLocks[id] = true

	local wasFav   = EstaEnFavoritos(id)
	local nextFav  = not wasFav

	-- 1. UI optimista: actualizar todas las cards y el array local
	if nextFav then
		table.insert(EmotesFavs, id)
	else
		local idx = table.find(EmotesFavs, id)
		if idx then table.remove(EmotesFavs, idx) end
	end
	SyncFavAcrossTabs(id, nextFav)

	-- 2. Quitar card de FAVS si corresponde
	if not nextFav then
		local animate = (TabActual == "FAVORITOS")
		RemoveCardFromScroll(ScrollFavs, id, animate)
		if #EmotesFavs == 0 and TabActual == "FAVORITOS" then
			MostrarEmptyMessage(true, "Sin favoritos\nToca el ícono en cualquier baile")
		end
	end

	-- 3. Servidor (en background): si falla o devuelve estado contrario, revertir
	task.spawn(function()
		local ok, status = pcall(function()
			return AnadirFav:InvokeServer(id)
		end)

		local serverFav
		if ok and status == "Anadido" then serverFav = true
		elseif ok and status == "Eliminada" then serverFav = false
		end

		if not ok then
			-- Error de red: revertir
			if nextFav then
				local idx = table.find(EmotesFavs, id)
				if idx then table.remove(EmotesFavs, idx) end
			else
				table.insert(EmotesFavs, id)
			end
			SyncFavAcrossTabs(id, wasFav)
			NotificationSystem:Error("Error", "Sin conexión", 2)
		elseif serverFav ~= nil and serverFav ~= nextFav then
			-- Servidor estaba en estado distinto (desync): forzar el del servidor
			if serverFav then
				if not table.find(EmotesFavs, id) then table.insert(EmotesFavs, id) end
			else
				local idx = table.find(EmotesFavs, id)
				if idx then table.remove(EmotesFavs, idx) end
			end
			SyncFavAcrossTabs(id, serverFav)
		else
			-- OK: notificar
			NotificationSystem:Success("Favorito", nombre .. (nextFav and " añadido" or " quitado"), 2)
		end

		FavLocks[id] = nil
	end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- CREAR TARJETA (con animación de favoritos mejorada)
-- ════════════════════════════════════════════════════════════════════════════════
local function CrearTarjeta(nombre, id, orden, ocultarFav, targetScroll)
	local esFavorito = (not ocultarFav) and EstaEnFavoritos(id)
	local cardHeight = GetCardHeight()

	-- Colores desde ThemeConfig
	local cardColorNormal = THEME_CONFIG.card
	local cardColorHover = THEME_CONFIG.elevated

	local card = Instance.new("TextButton")
	card.Name = "Card_" .. id
	card.Size = UDim2.new(1, 0, 0, cardHeight)
	card.BackgroundColor3 = cardColorNormal
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.LayoutOrder = orden
	card.Text = ""
	card.AutoButtonColor = false
	card:SetAttribute("Entry", true)
	card:SetAttribute("ID", id)
	card:SetAttribute("Name", nombre)
	card:SetAttribute("IsFavorite", esFavorito)
	card.Parent = targetScroll or ActiveScroll

	CreateCorner(card, IsMobile and 6 or 8)

	-- Overlay para efecto activo
	local activeOverlay = Instance.new("Frame")
	activeOverlay.Name = "ActiveOverlay"
	activeOverlay.Size = UDim2.new(1, 0, 1, 0)
	activeOverlay.BackgroundColor3 = THEME_CONFIG.accent
	activeOverlay.BackgroundTransparency = 1
	activeOverlay.BorderSizePixel = 0
	activeOverlay.ZIndex = 2
	activeOverlay.Parent = card
	CreateCorner(activeOverlay, IsMobile and 5 or 8)

	-- Borde activo
	local activeBorder = Instance.new("UIStroke")
	activeBorder.Name = "ActiveBorder"
	activeBorder.Color = THEME_CONFIG.accent
	activeBorder.Thickness = 2
	activeBorder.Transparency = 1
	activeBorder.Parent = card

	-- Nombre
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, IsMobile and -30 or -40, 1, 0)
	nameLabel.Position = UDim2.new(0, IsMobile and 8 or 12, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = nombre
	nameLabel.TextColor3 = THEME_CONFIG.text
	nameLabel.TextSize = IsMobile and 13 or 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 3
	nameLabel.Parent = card

	-- Contenedor del botón favorito (más pequeño, pegado a la derecha)
	local favContainer = Instance.new("Frame")
	favContainer.Name = "FavContainer"
	favContainer.Size = UDim2.new(0, IsMobile and 22 or 26, 0, IsMobile and 22 or 26)
	favContainer.Position = UDim2.new(1, IsMobile and -10 or -12, 0.5, 0)
	favContainer.AnchorPoint = Vector2.new(1, 0.5)
	favContainer.BackgroundTransparency = 1
	favContainer.ZIndex = 4
	favContainer.Parent = card

	-- Botón favorito (ImageButton para mejor calidad)
	local favBtn = Instance.new("ImageButton")
	favBtn.Name = "FavBtn"
	favBtn.Size = UDim2.new(1, 0, 1, 0)
	favBtn.BackgroundTransparency = 1
	favBtn.ZIndex = 5
	favBtn.Parent = favContainer
	ApplyFavBtnState(favBtn, esFavorito)

	-- Ocultar botón favorito para poses/emotes
	if ocultarFav then
		favContainer.Visible = false
		nameLabel.Size = UDim2.new(1, IsMobile and -8 or -12, 1, 0)
	end

	-- Variable para evitar clicks múltiples en la card (separado del lock global de fav)
	local isProcessingClick = false

	-- Hover en tarjeta
	TrackConnection(card, card.MouseEnter:Connect(function()
		Tween(card, 0.07, {BackgroundColor3 = cardColorHover}, Enum.EasingStyle.Quad)
	end))

	TrackConnection(card, card.MouseLeave:Connect(function()
		Tween(card, 0.07, {BackgroundColor3 = cardColorNormal}, Enum.EasingStyle.Quad)
	end))

	-- Click tarjeta (reproducir baile)
	TrackConnection(card, card.MouseButton1Click:Connect(function()
		if isProcessingClick or IsSynced then return end
		isProcessingClick = true

		if ActiveCard and ActiveCard.Parent and ActiveCard ~= card then
			RemoverEfectoActivo(ActiveCard)
		end

		DanceActivated = nombre
		ActiveCard = card
		PlayAnimationRemote:FireServer("playAnim", nombre, currentSpeed)
		AplicarEfectoActivo(card)
		ShowStopButton(true)

		task.delay(0.1, function() isProcessingClick = false end)
	end))

	-- Click favorito (delegado a ToggleFavorite con lock global por ID)
	TrackConnection(card, favBtn.MouseButton1Click:Connect(function()
		ToggleFavorite(id, nombre, card)
	end))

	return card
end

-- ════════════════════════════════════════════════════════════════════════════════
-- CARGAR CONTENIDO
-- ════════════════════════════════════════════════════════════════════════════════

local function LimpiarScroll(sf)
	sf = sf or ActiveScroll
	for _, child in ipairs(sf:GetChildren()) do
		if child:GetAttribute("Entry") then
			CleanupCard(child)
			if child == ActiveCard then ActiveCard = nil end
			child:Destroy()
		end
	end
	CardCache = {}
	MostrarEmptyMessage(false)
end

local function RestaurarBaileActivo()
	UpdateCardCache()
	if not DanceActivated then return end

	local card = CardCache[DanceActivated]
	if card then
		-- Limpiar efecto del frame anterior si cambió
		if ActiveCard and ActiveCard.Parent and ActiveCard ~= card then
			RemoverEfectoActivo(ActiveCard)
		end
		ActiveCard = card
		AplicarEfectoActivo(card)
	end
end

local function CargarPoses(filtro)
	filtro = (filtro or ""):lower()
	if PosesFilter == filtro then
		RestaurarBaileActivo()
		return
	end
	PosesFilter = filtro
	LimpiarScroll(ScrollPoses)

	local orden = 1
	local hayVisibles = false

	local function pasaFiltro(nombre)
		return filtro == "" or nombre:lower():find(filtro, 1, true)
	end

	for _, v in ipairs(Modulo.Emotes or {}) do
		if pasaFiltro(v.Nombre) then
			CrearTarjeta(v.Nombre, v.ID, orden, true, ScrollPoses)
			orden = orden + 1
			hayVisibles = true
		end
	end

	if not hayVisibles then
		MostrarEmptyMessage(true, filtro ~= "" and "Sin resultados" or "Sin poses aún")
	end

	RestaurarBaileActivo()
end

local function CargarDances(filtro)
	filtro = (filtro or ""):lower()
	if DancesFilter == filtro then
		RestaurarBaileActivo()
		return
	end
	DancesFilter = filtro
	LimpiarScroll(ScrollDances)

	local orden = 1

	local function pasaFiltro(nombre)
		return filtro == "" or nombre:lower():find(filtro, 1, true)
	end

	-- LISTA COMPLETA
	for _, v in ipairs(Modulo.Lista) do
		if pasaFiltro(v.Nombre) then
			CrearTarjeta(v.Nombre, v.ID, orden, nil, ScrollDances)
			orden = orden + 1
		end
	end

	RestaurarBaileActivo()
end

local function CargarFavoritos(filtro)
	LimpiarScroll(ScrollFavs)

	if #EmotesFavs == 0 then
		MostrarEmptyMessage(true, "Sin favoritos")
		return
	end

	filtro = (filtro or ""):lower()
	local orden = 1
	local hayVisibles = false

	for _, id in ipairs(EmotesFavs) do
		local nombre = EncontrarDatos(id)
		if filtro == "" or nombre:lower():find(filtro, 1, true) then
			CrearTarjeta(nombre, id, orden, nil, ScrollFavs)
			orden = orden + 1
			hayVisibles = true
		end
	end

	if not hayVisibles then
		MostrarEmptyMessage(true, "Sin resultados")
	end

	RestaurarBaileActivo()
end

-- ════════════════════════════════════════════════════════════════════════════════
-- CAMBIO DE TABS 
-- ════════════════════════════════════════════════════════════════════════════════

subTabs.onSwitch = function(tabId)
	ShowTab(tabId)    -- oculta tab anterior, muestra nueva (usa TabActual viejo)
	TabActual = tabId -- actualizar DESPUÉS de ShowTab
	local filtro = SearchBox and SearchBox.Text or ""
	if tabId == "POSES" then
		CargarPoses(filtro)
	elseif tabId == "DANCES" then
		CargarDances(filtro)
	else
		CargarFavoritos(filtro)
	end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- BÚSQUEDA
-- ════════════════════════════════════════════════════════════════════════════════

if SearchBox then
	local searchDebounce = false
	TrackGlobalConnection(SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if searchDebounce then return end
		searchDebounce = true
		task.delay(0.25, function()
			if TabActual == "POSES" then
				CargarPoses(SearchBox.Text)
			elseif TabActual == "DANCES" then
				CargarDances(SearchBox.Text)
			else
				CargarFavoritos(SearchBox.Text)
			end
			searchDebounce = false
		end)
	end))
end

-- ════════════════════════════════════════════════════════════════════════════════
-- TOGGLE GUI
-- ════════════════════════════════════════════════════════════════════════════════

local function ToggleGUI(visible)
	if visible == emotesPanelOpen then
		return
	end
	emotesPanelOpen = visible

	local posicionFinal = IsMobile 
		and UDim2.new(0, Config.Movil_MargenIzquierdo, 0.5, Config.Movil_OffsetVertical)
		or UDim2.new(0, Config.PC_MargenIzquierdo, 0.5, Config.PC_OffsetVertical)

	local posicionOculta = IsMobile
		and UDim2.new(0, -Config.Movil_Ancho, 0.5, Config.Movil_OffsetVertical)
		or UDim2.new(0, -Config.PC_Ancho, 0.5, Config.PC_OffsetVertical)

	if visible then
		Tween(MainFrame, 0.3, {Position = posicionFinal}, Enum.EasingStyle.Back)
	else
		StopSliderDrag() -- Resetear slider al cerrar panel
		Tween(MainFrame, 0.25, {Position = posicionOculta}, Enum.EasingStyle.Quint)
	end
end

-- Conectar botón toggle
ToggleBtn.MouseButton1Click:Connect(function()
	ToggleGUI(not emotesPanelOpen)
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- LIMPIEZA AL DESTRUIR
-- ════════════════════════════════════════════════════════════════════════════════

ScreenGui.Destroying:Connect(function()
	CleanupAllCards()

	for _, conn in ipairs(GlobalConnections) do
		if conn then pcall(function() conn:Disconnect() end) end
	end
	GlobalConnections = {}
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- INICIALIZACIÓN
-- ════════════════════════════════════════════════════════════════════════════════

-- Precargar todas las animaciones en el CLIENTE en background
-- Esto evita la demora la primera vez que se usa un baile
task.spawn(function()
	local ContentProvider = game:GetService("ContentProvider")
	local preloadList = {}
	for _, v in ipairs(Modulo.Lista or {}) do
		if v.ID and v.ID ~= 0 then
			local a = Instance.new("Animation")
			a.AnimationId = "rbxassetid://" .. tostring(v.ID)
			table.insert(preloadList, a)
		end
	end
	if Modulo.Emotes then
		for _, v in ipairs(Modulo.Emotes) do
			if v.ID and v.ID ~= 0 then
				local a = Instance.new("Animation")
				a.AnimationId = "rbxassetid://" .. tostring(v.ID)
				table.insert(preloadList, a)
			end
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(preloadList)
	end)
end)

local ok, favs = pcall(function() return ObtenerFavs:InvokeServer() end)
EmotesFavs = (ok and favs) or {}
CargarPoses()

-- ════════════════════════════════════════════════════════════════════════════════
-- GLOBAL FUNCTIONS (Para TOPBAR.lua)
-- ════════════════════════════════════════════════════════════════════════════════
_G.OpenEmotesUI = function() ToggleGUI(true) end
_G.CloseEmotesUI = function() ToggleGUI(false) end