--[[
	═══════════════════════════════════════════════════════════════════════════════
	   EMOTES SYSTEM 
	═══════════════════════════════════════════════════════════════════════════════
]]--

-- ════════════════════════════════════════════════════════════════════════════════
-- CONFIGURACIÓN
-- ════════════════════════════════════════════════════════════════════════════════

local Config = {
	PC_Ancho              = 250,
	PC_Alto               = 500,
	PC_MargenIzquierdo    = 6,
	PC_OffsetVertical     = 120,
	Movil_Ancho           = 175,
	Movil_Alto            = 320,
	Movil_MargenIzquierdo = 4,
	Movil_OffsetVertical  = 10,
	Movil_MostrarBusqueda = true,
}

-- ════════════════════════════════════════════════════════════════════════════════
-- SERVICIOS
-- ════════════════════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ════════════════════════════════════════════════════════════════════════════════
-- REFERENCIAS
-- ════════════════════════════════════════════════════════════════════════════════

local Replicado   = ReplicatedStorage:WaitForChild("RemotesGlobal")
local Remotos     = Replicado:WaitForChild("Eventos_Emote")
local RemotesSync = Replicado:WaitForChild("Emotes_Sync")

local ObtenerFavs         = Remotos:WaitForChild("ObtenerFavs")
local AnadirFav           = Remotos:WaitForChild("AnadirFav")
local PlayAnimationRemote = RemotesSync:FindFirstChild("PlayAnimation")
local StopAnimationRemote = RemotesSync:FindFirstChild("StopAnimation")
local SyncRemote          = RemotesSync:FindFirstChild("Sync")

local THEME_CONFIG       = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThemeConfig"))
local Modulo             = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Animaciones"))
local NotificationSystem = require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("NotificationSystem"):WaitForChild("NotificationSystem"))
local ModernScrollbar    = require(ReplicatedStorage:WaitForChild("UIComponents"):WaitForChild("ModernScrollbar"))
local SubTabs            = require(ReplicatedStorage:WaitForChild("UIComponents"):WaitForChild("SubTabs"))

-- ════════════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ════════════════════════════════════════════════════════════════════════════════

local Jugador    = Players.LocalPlayer
local PlayerGui  = Jugador:WaitForChild("PlayerGui")

local IsMobile            = UserInputService.TouchEnabled
local EmotesFavs          = {}
local DanceActivated      = nil
local ActiveCard          = nil
local TabActual           = "POSES"
local IsSynced            = false
local currentLeaderUserId = nil
local emotesPanelOpen     = false

local CardConnections   = {}
local ActiveTweens      = {}
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
	s.Color        = color or THEME_CONFIG.stroke
	s.Thickness    = thickness or 1
	s.Transparency = transparency or 0
	s.Parent       = parent
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
-- GESTIÓN DE MEMORIA
-- ════════════════════════════════════════════════════════════════════════════════

local function TrackConnection(card, connection)
	if not card then return end
	if not CardConnections[card] then CardConnections[card] = {} end
	table.insert(CardConnections[card], connection)
end

local function TrackGlobalConnection(connection)
	table.insert(GlobalConnections, connection)
end

local function TrackTween(card, tween)
	if not card or not tween then return end
	if not ActiveTweens[card] then ActiveTweens[card] = {} end
	table.insert(ActiveTweens[card], tween)
end

local function CleanupCard(card)
	if not card then return end
	if ActiveTweens[card] then
		for _, t in ipairs(ActiveTweens[card]) do
			if t then pcall(function() t:Cancel() end) end
		end
		ActiveTweens[card] = nil
	end
	if CardConnections[card] then
		for _, conn in ipairs(CardConnections[card]) do
			if conn then pcall(function() conn:Disconnect() end) end
		end
		CardConnections[card] = nil
	end
end

local function CleanupAllCards()
	for card in pairs(CardConnections) do CleanupCard(card) end
	for card in pairs(ActiveTweens) do
		if ActiveTweens[card] then
			for _, t in ipairs(ActiveTweens[card]) do
				if t then pcall(function() t:Cancel() end) end
			end
		end
	end
	CardConnections = {}
	ActiveTweens    = {}
end

-- ════════════════════════════════════════════════════════════════════════════════
-- ANIMACIÓN ACTIVA
-- ════════════════════════════════════════════════════════════════════════════════

local function AplicarEfectoActivo(card)
	if not card or not card.Parent then return end
	local border  = card:FindFirstChild("ActiveBorder")
	local overlay = card:FindFirstChild("ActiveOverlay")
	if border  then TrackTween(card, Tween(border,  0.12, {Transparency = 0, Thickness = 2}, Enum.EasingStyle.Quad)) end
	if overlay then TrackTween(card, Tween(overlay, 0.12, {BackgroundTransparency = 0.8},    Enum.EasingStyle.Quad)) end
end

local function RemoverEfectoActivo(card)
	if not card or not card.Parent then return end
	local border  = card:FindFirstChild("ActiveBorder")
	local overlay = card:FindFirstChild("ActiveOverlay")
	if border  then TrackTween(card, Tween(border,  0.08, {Transparency = 1, Thickness = 2}, Enum.EasingStyle.Quad)) end
	if overlay then TrackTween(card, Tween(overlay, 0.08, {BackgroundTransparency = 1},       Enum.EasingStyle.Quad)) end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- GUI PRINCIPAL
-- ════════════════════════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "EmotesModernUI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset  = true
ScreenGui.Parent          = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name                   = "MainFrame"
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel        = 0
MainFrame.Visible                = true
MainFrame.AnchorPoint            = Vector2.new(0, 0.5)
MainFrame.ClipsDescendants       = false
MainFrame.Parent                 = ScreenGui

local function ActualizarTamanoFrame()
	if IsMobile then
		MainFrame.Size     = UDim2.new(0, Config.Movil_Ancho, 0, Config.Movil_Alto)
		MainFrame.Position = UDim2.new(0, -Config.Movil_Ancho, 0.5, Config.Movil_OffsetVertical)
	else
		MainFrame.Size     = UDim2.new(0, Config.PC_Ancho, 0, Config.PC_Alto)
		MainFrame.Position = UDim2.new(0, -Config.PC_Ancho, 0.5, Config.PC_OffsetVertical)
	end
end
ActualizarTamanoFrame()

local ContentCanvas = Instance.new("CanvasGroup")
ContentCanvas.Name                   = "ContentCanvas"
ContentCanvas.Size                   = UDim2.new(1, 0, 1, 0)
ContentCanvas.BackgroundColor3       = THEME_CONFIG.bg
ContentCanvas.BackgroundTransparency = 0
ContentCanvas.BorderSizePixel        = 0
ContentCanvas.Parent                 = MainFrame
CreateCorner(ContentCanvas, 12)
CreateStroke(ContentCanvas, THEME_CONFIG.stroke, 1, 0.5)

-- ════════════════════════════════════════════════════════════════════════════════
-- BOTÓN TOGGLE
-- ════════════════════════════════════════════════════════════════════════════════

local btnSize = IsMobile and 40 or 45

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Name                   = "EmoteToggle"
ToggleBtn.Size                   = UDim2.new(0, btnSize, 0, btnSize)
ToggleBtn.Position               = UDim2.new(1, 4, 0.5, 0)
ToggleBtn.AnchorPoint            = Vector2.new(0, 0.5)
ToggleBtn.BackgroundColor3       = THEME_CONFIG.bg
ToggleBtn.BackgroundTransparency = 0
ToggleBtn.Image                  = ""
ToggleBtn.AutoButtonColor        = false
ToggleBtn.ZIndex                 = 10
ToggleBtn.Parent                 = MainFrame
CreateCorner(ToggleBtn, btnSize / 2)
CreateStroke(ToggleBtn, THEME_CONFIG.stroke, 1, 0.5)

local ToggleIcon = Instance.new("ImageLabel")
ToggleIcon.Image                  = "rbxassetid://88883622923552"
ToggleIcon.ImageColor3            = THEME_CONFIG.text
ToggleIcon.BackgroundTransparency = 1
ToggleIcon.Size                   = UDim2.new(1, -12, 1, -12)
ToggleIcon.Position               = UDim2.new(0.5, 0, 0.5, 0)
ToggleIcon.AnchorPoint            = Vector2.new(0.5, 0.5)
ToggleIcon.ScaleType              = Enum.ScaleType.Fit
ToggleIcon.ZIndex                 = 11
ToggleIcon.Parent                 = ToggleBtn

ToggleBtn.MouseEnter:Connect(function()
	Tween(ToggleBtn, 0.07, {BackgroundColor3 = THEME_CONFIG.elevated}, Enum.EasingStyle.Quad)
end)
ToggleBtn.MouseLeave:Connect(function()
	Tween(ToggleBtn, 0.07, {BackgroundColor3 = THEME_CONFIG.bg}, Enum.EasingStyle.Quad)
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- TABS
-- ════════════════════════════════════════════════════════════════════════════════

local tabHeight = IsMobile and 38 or 46

local subTabs = SubTabs.new(ContentCanvas, THEME_CONFIG, {
	tabs = {
		{ id = "POSES",     label = "POSES"  },
		{ id = "DANCES",    label = "DANCES" },
		{ id = "FAVORITOS", label = "FAVS"   },
	},
	height   = tabHeight,
	default  = "POSES",
	textSize = IsMobile and 13 or 15,
})

local posY = tabHeight

-- ════════════════════════════════════════════════════════════════════════════════
-- BÚSQUEDA
-- ════════════════════════════════════════════════════════════════════════════════

local mostrarBusqueda = IsMobile and Config.Movil_MostrarBusqueda or true
local SearchContainer, SearchBox

if mostrarBusqueda then
	SearchContainer = Instance.new("Frame")
	SearchContainer.Name                   = "SearchContainer"
	SearchContainer.Size                   = UDim2.new(1, 0, 0, IsMobile and 32 or 40)
	SearchContainer.Position               = UDim2.new(0, 0, 0, posY)
	SearchContainer.BackgroundTransparency = 1
	SearchContainer.BorderSizePixel        = 0
	SearchContainer.ClipsDescendants       = true
	SearchContainer.Parent                 = ContentCanvas

	local SearchIconContainer = Instance.new("Frame")
	SearchIconContainer.Size                   = UDim2.new(0, IsMobile and 20 or 26, 1, 0)
	SearchIconContainer.Position               = UDim2.new(0, IsMobile and 4 or 6, 0, 0)
	SearchIconContainer.BackgroundTransparency = 1
	SearchIconContainer.Parent                 = SearchContainer

	local SearchCircle = Instance.new("Frame")
	SearchCircle.Size                   = UDim2.new(0, IsMobile and 10 or 12, 0, IsMobile and 10 or 12)
	SearchCircle.Position               = UDim2.new(0.5, IsMobile and -6 or -7, 0.5, IsMobile and -6 or -7)
	SearchCircle.BackgroundTransparency = 1
	SearchCircle.Parent                 = SearchIconContainer
	CreateCorner(SearchCircle, 100)
	local circleStroke = CreateStroke(SearchCircle, THEME_CONFIG.subtle, IsMobile and 1.5 or 2, 0.3)

	local SearchHandle = Instance.new("Frame")
	SearchHandle.Size                   = UDim2.new(0, IsMobile and 5 or 6, 0, IsMobile and 1.5 or 2)
	SearchHandle.Position               = UDim2.new(0.5, IsMobile and 2 or 3, 0.5, IsMobile and 3 or 4)
	SearchHandle.Rotation               = 45
	SearchHandle.BackgroundColor3       = THEME_CONFIG.subtle
	SearchHandle.BackgroundTransparency = THEME_CONFIG.lightAlpha
	SearchHandle.BorderSizePixel        = 0
	SearchHandle.Parent                 = SearchIconContainer
	CreateCorner(SearchHandle, 2)

	SearchBox = Instance.new("TextBox")
	SearchBox.Name              = "SearchBox"
	SearchBox.Size              = UDim2.new(1, IsMobile and -28 or -36, 1, 0)
	SearchBox.Position          = UDim2.new(0, IsMobile and 24 or 30, 0, 0)
	SearchBox.BackgroundTransparency = 1
	SearchBox.Font              = Enum.Font.GothamMedium
	SearchBox.PlaceholderText   = "Buscar baile..."
	SearchBox.PlaceholderColor3 = THEME_CONFIG.subtle
	SearchBox.Text              = ""
	SearchBox.TextColor3        = THEME_CONFIG.text
	SearchBox.TextSize          = IsMobile and 13 or 15
	SearchBox.TextXAlignment    = Enum.TextXAlignment.Left
	SearchBox.TextTruncate      = Enum.TextTruncate.AtEnd
	SearchBox.ClearTextOnFocus  = false
	SearchBox.ClipsDescendants  = true
	SearchBox.Parent            = SearchContainer

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
-- DIMENSIONES ZONA INFERIOR
-- ════════════════════════════════════════════════════════════════════════════════

local sliderH  = IsMobile and 44 or 66
local stopBtnH = IsMobile and 24 or 36

-- ════════════════════════════════════════════════════════════════════════════════
-- ÁREA DE CONTENIDO
-- ════════════════════════════════════════════════════════════════════════════════

local ContentArea = Instance.new("Frame")
ContentArea.Name                   = "ContentArea"
ContentArea.Size                   = UDim2.new(1, 0, 1, -(posY + sliderH))
ContentArea.Position               = UDim2.new(0, 0, 0, posY)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants       = true
ContentArea.Parent                 = ContentCanvas

-- ════════════════════════════════════════════════════════════════════════════════
-- SCROLL FRAMES (uno por pestaña)
-- Definidos ANTES de StopButton y ShowStopButton para evitar referencias nil
-- ════════════════════════════════════════════════════════════════════════════════

local function CrearScrollFrame(nombre)
	local sf = Instance.new("ScrollingFrame")
	sf.Name                       = nombre
	sf.Size                       = UDim2.new(1, 0, 1, 0)
	sf.BackgroundTransparency     = 1
	sf.BorderSizePixel            = 0
	sf.ScrollBarThickness         = 0
	sf.ScrollBarImageTransparency = 1
	sf.CanvasSize                 = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize        = Enum.AutomaticSize.Y
	sf.ScrollingDirection         = Enum.ScrollingDirection.Y
	sf.Parent                     = ContentArea

	local layout = Instance.new("UIListLayout")
	layout.SortOrder           = Enum.SortOrder.LayoutOrder
	layout.Padding             = UDim.new(0, IsMobile and 3 or 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent              = sf

	local pad = Instance.new("UIPadding")
	pad.PaddingTop    = UDim.new(0, IsMobile and 2 or 4)
	pad.PaddingBottom = UDim.new(0, IsMobile and 4 or 10)
	pad.PaddingLeft   = UDim.new(0, IsMobile and 4 or 6)
	pad.PaddingRight  = UDim.new(0, IsMobile and 4 or 6)
	pad.Parent        = sf

	local emptyMsg = Instance.new("TextLabel")
	emptyMsg.Name                   = "EmptyMessage"
	emptyMsg.Size                   = UDim2.new(0, 0, 0, 0)
	emptyMsg.BackgroundTransparency = 1
	emptyMsg.Font                   = Enum.Font.GothamMedium
	emptyMsg.Text                   = "Sin favoritos\nToca el ícono en cualquier baile"
	emptyMsg.TextColor3             = THEME_CONFIG.subtle
	emptyMsg.TextSize               = IsMobile and 13 or 15
	emptyMsg.TextWrapped            = true
	emptyMsg.Visible                = false
	emptyMsg.LayoutOrder            = 999
	emptyMsg.Parent                 = sf

	ModernScrollbar.setup(sf, ContentArea, THEME_CONFIG, { color = THEME_CONFIG.accent, offset = -6, transparency = 0 })

	return sf, emptyMsg
end

local ScrollPoses,  EmptyPoses  = CrearScrollFrame("ScrollPoses")
local ScrollDances, EmptyDances = CrearScrollFrame("ScrollDances")
local ScrollFavs,   EmptyFavs   = CrearScrollFrame("ScrollFavs")

ScrollDances.Visible = false
ScrollFavs.Visible   = false

local ActiveScroll = ScrollPoses
local ActiveEmpty  = EmptyPoses

-- ════════════════════════════════════════════════════════════════════════════════
-- BOTÓN STOP
-- Definido DESPUÉS de los ScrollFrames para que ShowStopButton pueda usarlos
-- ════════════════════════════════════════════════════════════════════════════════

local StopButton = Instance.new("TextButton")
StopButton.Name                   = "StopButton"
StopButton.Size                   = UDim2.new(1, 0, 0, stopBtnH)
StopButton.Position               = UDim2.new(0, 0, 1, -stopBtnH)
StopButton.BackgroundColor3       = THEME_CONFIG.card
StopButton.BackgroundTransparency = 0
StopButton.BorderSizePixel        = 0
StopButton.Text                   = "■  DETENER"
StopButton.Font                   = Enum.Font.GothamBold
StopButton.TextSize               = IsMobile and 10 or 13
StopButton.TextColor3             = THEME_CONFIG.accent
StopButton.AutoButtonColor        = false
StopButton.ZIndex                 = 6
StopButton.Visible                = false
StopButton.Parent                 = ContentArea

local StopSep = Instance.new("Frame")
StopSep.Size                   = UDim2.new(1, 0, 0, 1)
StopSep.Position               = UDim2.new(0, 0, 0, 0)
StopSep.BackgroundColor3       = THEME_CONFIG.stroke
StopSep.BackgroundTransparency = 0.4
StopSep.BorderSizePixel        = 0
StopSep.ZIndex                 = 7
StopSep.Parent                 = StopButton

StopButton.MouseEnter:Connect(function()
	Tween(StopButton, 0.07, {BackgroundColor3 = THEME_CONFIG.elevated, TextColor3 = THEME_CONFIG.text}, Enum.EasingStyle.Quad)
end)
StopButton.MouseLeave:Connect(function()
	Tween(StopButton, 0.07, {BackgroundColor3 = THEME_CONFIG.card, TextColor3 = THEME_CONFIG.accent}, Enum.EasingStyle.Quad)
end)

-- FIX #1: ShowStopButton ahora está definida DESPUÉS de los ScrollFrames,
-- así ScrollPoses/ScrollDances/ScrollFavs ya existen y no son nil.
local function ShowStopButton(show)
	StopButton.Visible = show
	local shrink = show and stopBtnH or 0
	ScrollPoses.Size  = UDim2.new(1, 0, 1, -shrink)
	ScrollDances.Size = UDim2.new(1, 0, 1, -shrink)
	ScrollFavs.Size   = UDim2.new(1, 0, 1, -shrink)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- OVERLAY DE SINCRONIZACIÓN
-- ════════════════════════════════════════════════════════════════════════════════

local SyncOverlay = Instance.new("TextButton")
SyncOverlay.Name                   = "SyncOverlay"
SyncOverlay.Size                   = UDim2.new(1, 0, 1, 0)
SyncOverlay.Position               = UDim2.new(0, 0, 0, 0)
SyncOverlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
SyncOverlay.BackgroundTransparency = THEME_CONFIG.lightAlpha
SyncOverlay.BorderSizePixel        = 0
SyncOverlay.Text                   = ""
SyncOverlay.AutoButtonColor        = false
SyncOverlay.ZIndex                 = 100
SyncOverlay.Visible                = false
SyncOverlay.Parent                 = ContentArea
CreateCorner(SyncOverlay, IsMobile and 8 or 12)

local SyncPlayerName = Instance.new("TextLabel")
SyncPlayerName.Name                   = "SyncPlayerName"
SyncPlayerName.Size                   = UDim2.new(1, -20, 0, IsMobile and 30 or 36)
SyncPlayerName.Position               = UDim2.new(0, 10, 0.5, IsMobile and -22 or -26)
SyncPlayerName.BackgroundTransparency = 1
SyncPlayerName.Font                   = Enum.Font.GothamBold
SyncPlayerName.Text                   = "Player Name"
SyncPlayerName.TextColor3             = THEME_CONFIG.accent
SyncPlayerName.TextSize               = IsMobile and 20 or 24
SyncPlayerName.TextTruncate           = Enum.TextTruncate.AtEnd
SyncPlayerName.TextXAlignment         = Enum.TextXAlignment.Center
SyncPlayerName.ZIndex                 = 101
SyncPlayerName.Parent                 = SyncOverlay

local SyncHint = Instance.new("TextLabel")
SyncHint.Name                   = "SyncHint"
SyncHint.Size                   = UDim2.new(1, -20, 0, IsMobile and 14 or 16)
SyncHint.Position               = UDim2.new(0, 10, 0.5, IsMobile and 10 or 12)
SyncHint.BackgroundTransparency = 1
SyncHint.Font                   = Enum.Font.GothamBold
SyncHint.Text                   = "Toca para desincronizarte"
SyncHint.TextColor3             = THEME_CONFIG.subtle
SyncHint.TextSize               = IsMobile and 12 or 14
SyncHint.TextXAlignment         = Enum.TextXAlignment.Center
SyncHint.ZIndex                 = 101
SyncHint.Parent                 = SyncOverlay

local function SetSyncOverlay(synced, syncedPlayerName)
	IsSynced = synced
	if synced then
		SyncPlayerName.Text                = syncedPlayerName or "Desconocido"
		SyncOverlay.BackgroundTransparency = 1
		SyncOverlay.Visible                = true
		Tween(SyncOverlay, 0.3, {BackgroundTransparency = THEME_CONFIG.lightAlpha})
	else
		local t = Tween(SyncOverlay, 0.3, {BackgroundTransparency = 1})
		if t then t.Completed:Connect(function() SyncOverlay.Visible = false end) end
	end
end

SyncOverlay.MouseButton1Click:Connect(function()
	if SyncRemote then
		SyncRemote:FireServer("unsync")
		SetSyncOverlay(false)
		NotificationSystem:Info("Sync", "Te has desincronizado", 2)
	end
end)
SyncOverlay.MouseEnter:Connect(function()
	Tween(SyncPlayerName, 0.15, {TextColor3 = Color3.fromRGB(255, 255, 255)})
end)
SyncOverlay.MouseLeave:Connect(function()
	Tween(SyncPlayerName, 0.15, {TextColor3 = THEME_CONFIG.accent})
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- BARRA DE VELOCIDAD
-- ════════════════════════════════════════════════════════════════════════════════

local MIN_SPEED    = 0.1
local MAX_SPEED    = 3.0
local currentSpeed = 1.0
local isDragging   = false
local speedTask    = nil

local SliderSep = Instance.new("Frame")
SliderSep.Size                   = UDim2.new(1, 0, 0, 1)
SliderSep.Position               = UDim2.new(0, 0, 1, -sliderH)
SliderSep.BackgroundColor3       = THEME_CONFIG.stroke
SliderSep.BackgroundTransparency = 0.5
SliderSep.BorderSizePixel        = 0
SliderSep.ZIndex                 = 5
SliderSep.Parent                 = ContentCanvas

local SpeedContainer = Instance.new("Frame")
SpeedContainer.Name                   = "SpeedContainer"
SpeedContainer.Size                   = UDim2.new(1, 0, 0, sliderH - 1)
SpeedContainer.Position               = UDim2.new(0, 0, 1, -(sliderH - 1))
SpeedContainer.BackgroundColor3       = THEME_CONFIG.card
SpeedContainer.BackgroundTransparency = 0
SpeedContainer.BorderSizePixel        = 0
SpeedContainer.ZIndex                 = 5
SpeedContainer.Parent                 = ContentCanvas

local speedPadH  = IsMobile and 8 or 12
local speedPadV  = IsMobile and 5 or 10
local trackH_sz  = IsMobile and 6 or 10
local thumbSz    = IsMobile and 16 or 26
local headerH    = IsMobile and 14 or 20
local trackAreaH = sliderH - 1 - headerH - speedPadV * 2

local SpeedLabelRow = Instance.new("Frame")
SpeedLabelRow.Size                   = UDim2.new(1, -speedPadH * 2, 0, headerH)
SpeedLabelRow.Position               = UDim2.new(0, speedPadH, 0, speedPadV)
SpeedLabelRow.BackgroundTransparency = 1
SpeedLabelRow.ZIndex                 = 6
SpeedLabelRow.Parent                 = SpeedContainer

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size                   = UDim2.new(0.5, 0, 1, 0)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text                   = "VELOCIDAD"
SpeedLabel.TextColor3             = THEME_CONFIG.subtle
SpeedLabel.TextSize               = IsMobile and 8 or 11
SpeedLabel.Font                   = Enum.Font.GothamBold
SpeedLabel.TextXAlignment         = Enum.TextXAlignment.Left
SpeedLabel.ZIndex                 = 6
SpeedLabel.Parent                 = SpeedLabelRow

local SpeedValue = Instance.new("TextLabel")
SpeedValue.Name                   = "SpeedValue"
SpeedValue.Size                   = UDim2.new(0.5, 0, 1, 0)
SpeedValue.Position               = UDim2.new(0.5, 0, 0, 0)
SpeedValue.BackgroundTransparency = 1
SpeedValue.Text                   = "1.0×"
SpeedValue.TextColor3             = THEME_CONFIG.text
SpeedValue.TextSize               = IsMobile and 8 or 11
SpeedValue.Font                   = Enum.Font.GothamBold
SpeedValue.TextXAlignment         = Enum.TextXAlignment.Right
SpeedValue.ZIndex                 = 6
SpeedValue.Parent                 = SpeedLabelRow

local trackY = speedPadV + headerH + math.floor((trackAreaH - trackH_sz) / 2)

local SliderTrack = Instance.new("Frame")
SliderTrack.Name              = "SliderTrack"
SliderTrack.Size              = UDim2.new(1, -speedPadH * 2, 0, trackH_sz)
SliderTrack.Position          = UDim2.new(0, speedPadH, 0, trackY)
SliderTrack.BackgroundColor3  = THEME_CONFIG.elevated
SliderTrack.BackgroundTransparency = 0
SliderTrack.BorderSizePixel   = 0
SliderTrack.ZIndex            = 6
SliderTrack.ClipsDescendants  = false
SliderTrack.Parent            = SpeedContainer
CreateCorner(SliderTrack, 4)

local defaultFrac = (1.0 - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)

local SliderFill = Instance.new("Frame")
SliderFill.Name             = "SliderFill"
SliderFill.Size             = UDim2.new(defaultFrac, 0, 1, 0)
SliderFill.BackgroundColor3 = THEME_CONFIG.accent
SliderFill.BorderSizePixel  = 0
SliderFill.ZIndex           = 7
SliderFill.Parent           = SliderTrack
CreateCorner(SliderFill, 4)

local SliderThumb = Instance.new("Frame")
SliderThumb.Name             = "SliderThumb"
SliderThumb.Size             = UDim2.new(0, thumbSz, 0, thumbSz)
SliderThumb.AnchorPoint      = Vector2.new(0.5, 0.5)
SliderThumb.Position         = UDim2.new(defaultFrac, 0, 0.5, 0)
SliderThumb.BackgroundColor3 = THEME_CONFIG.text
SliderThumb.BorderSizePixel  = 0
SliderThumb.ZIndex           = 8
SliderThumb.Parent           = SliderTrack
CreateCorner(SliderThumb, thumbSz / 2)
CreateStroke(SliderThumb, THEME_CONFIG.bg, 2, 0)

local SliderHit = Instance.new("TextButton")
SliderHit.Name                   = "SliderHit"
SliderHit.Size                   = UDim2.new(1, 0, 1, 0)
SliderHit.BackgroundTransparency = 1
SliderHit.Text                   = ""
SliderHit.AutoButtonColor        = false
SliderHit.ZIndex                 = 9
SliderHit.Parent                 = SpeedContainer

local function UpdateSliderUI(spd)
	spd = math.clamp(spd, MIN_SPEED, MAX_SPEED)
	local frac = (spd - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
	SliderFill.Size      = UDim2.new(frac, 0, 1, 0)
	SliderThumb.Position = UDim2.new(frac, 0, 0.5, 0)
	local rounded = math.floor(spd * 10 + 0.5) / 10
	SpeedValue.Text = tostring(rounded) .. "×"
end

local function GetFrac(inputX)
	local abs = SliderTrack.AbsolutePosition
	local sz  = SliderTrack.AbsoluteSize
	if sz.X <= 0 then return 0 end
	return math.clamp((inputX - abs.X) / sz.X, 0, 1)
end

local function ApplySpeed(frac)
	if IsSynced then return end
	currentSpeed = math.clamp(MIN_SPEED + frac * (MAX_SPEED - MIN_SPEED), MIN_SPEED, MAX_SPEED)
	UpdateSliderUI(currentSpeed)
	if DanceActivated and PlayAnimationRemote then
		if speedTask then task.cancel(speedTask) end
		speedTask = task.delay(0.016, function()
			local r = math.floor(currentSpeed * 10 + 0.5) / 10
			PlayAnimationRemote:FireServer("setSpeed", r)
			speedTask = nil
		end)
	end
end

local function StopDrag()
	if not isDragging then return end
	isDragging = false
	if DanceActivated and PlayAnimationRemote then
		if speedTask then task.cancel(speedTask) end
		speedTask = nil
		local r = math.floor(currentSpeed * 10 + 0.5) / 10
		PlayAnimationRemote:FireServer("setSpeed", r)
	end
end

TrackGlobalConnection(SliderHit.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
		isDragging = true
		ApplySpeed(GetFrac(inp.Position.X))
	end
end))

TrackGlobalConnection(UserInputService.InputChanged:Connect(function(inp)
	if not isDragging then return end
	if inp.UserInputType == Enum.UserInputType.MouseMovement
		or inp.UserInputType == Enum.UserInputType.Touch then
		ApplySpeed(GetFrac(inp.Position.X))
	end
end))

TrackGlobalConnection(UserInputService.InputEnded:Connect(function(inp)
	if not isDragging then return end
	if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
		StopDrag()
	end
end))

-- ════════════════════════════════════════════════════════════════════════════════
-- HELPERS UI
-- ════════════════════════════════════════════════════════════════════════════════

-- FIX #2: CardCache busca en todos los scrolls, sin debounce de tiempo
-- para que setActiveByName siempre aplique el efecto visual correctamente.
local CardCache = {}

local function UpdateCardCache()
	CardCache = {}
	for _, sf in ipairs({ScrollPoses, ScrollDances, ScrollFavs}) do
		for _, child in ipairs(sf:GetChildren()) do
			local n = child:GetAttribute("Name")
			if n and not CardCache[n] then CardCache[n] = child end
		end
	end
end

-- FIX #3: Sin debounce de tiempo — el efecto siempre se aplica
local function setActiveByName(nombre)
	if not nombre then return end

	local card = CardCache[nombre]
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

	if card and card.Parent then
		if ActiveCard and ActiveCard.Parent and ActiveCard ~= card then
			RemoverEfectoActivo(ActiveCard)
		end
		ActiveCard     = card
		DanceActivated = nombre
		AplicarEfectoActivo(card)
		ShowStopButton(true)
	else
		DanceActivated = nombre
		ShowStopButton(true)
	end
end

local function clearActive()
	if ActiveCard and ActiveCard.Parent then RemoverEfectoActivo(ActiveCard) end
	ActiveCard     = nil
	DanceActivated = nil
	ShowStopButton(false)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- SHOW TAB — actualiza ActiveScroll y ActiveEmpty
-- ════════════════════════════════════════════════════════════════════════════════

local function ShowTab(tabAnterior, newTabId)
	local sfMap = { POSES = ScrollPoses, DANCES = ScrollDances, FAVORITOS = ScrollFavs }
	local emMap = { POSES = EmptyPoses,  DANCES = EmptyDances,  FAVORITOS = EmptyFavs  }
	-- Ocultar con el tab ANTERIOR (antes de que TabActual se pise)
	if sfMap[tabAnterior] then sfMap[tabAnterior].Visible = false end
	local sf = sfMap[newTabId]
	if sf then
		sf.Visible   = true
		ActiveScroll = sf
		ActiveEmpty  = emMap[newTabId]
	end
end

local function MostrarEmptyMessage(mostrar, texto)
	if not ActiveEmpty then return end
	if texto then ActiveEmpty.Text = texto end
	ActiveEmpty.Visible = mostrar
	ActiveEmpty.Size    = mostrar and UDim2.new(1, 0, 0, 60) or UDim2.new(0, 0, 0, 0)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- EVENTOS REMOTOS
-- ════════════════════════════════════════════════════════════════════════════════

if PlayAnimationRemote and PlayAnimationRemote:IsA("RemoteEvent") then
	TrackGlobalConnection(PlayAnimationRemote.OnClientEvent:Connect(function(action, payload)
		if action == "playAnim" and type(payload) == "string" then
			setActiveByName(payload)
		end
	end))
end

if StopAnimationRemote and StopAnimationRemote:IsA("RemoteEvent") then
	TrackGlobalConnection(StopAnimationRemote.OnClientEvent:Connect(function()
		clearActive()
	end))
end

local SyncUpdate = RemotesSync:FindFirstChild("SyncUpdate")
if SyncUpdate and SyncUpdate:IsA("RemoteEvent") then
	TrackGlobalConnection(SyncUpdate.OnClientEvent:Connect(function(payload)
		if not payload then return end

		if payload.followerNotification and payload.followerNames then
			local msg = #payload.followerNames == 1
				and payload.followerNames[1] .. " te está siguiendo"
				or  #payload.followerNames .. " personas te siguen"
			pcall(function() NotificationSystem:Info("Seguidores", msg, 4) end)
			return
		end

		if payload.isSynced ~= nil then
			-- FIX #4: Solo notificar sync la PRIMERA vez, no en cada cambio de baile
			local eraNuevoSync = (not IsSynced) and payload.isSynced
			SetSyncOverlay(payload.isSynced, payload.leaderName)
			if eraNuevoSync then
				pcall(function() NotificationSystem:Sync(payload.leaderName) end)
			end
		end

		if payload.syncError then
			pcall(function() NotificationSystem:Error("Sync", payload.syncError, 3) end)
		end

		if payload.leaderUserId ~= nil then
			currentLeaderUserId = payload.leaderUserId
		elseif payload.isSynced == false then
			currentLeaderUserId = nil
		end

		if payload.animationName and type(payload.animationName) == "string" and payload.animationName ~= "" then
			setActiveByName(payload.animationName)
		elseif payload.animationName == nil then
			clearActive()
		end

		if payload.speed ~= nil and IsSynced then
			currentSpeed = math.clamp(payload.speed, MIN_SPEED, MAX_SPEED)
			UpdateSliderUI(currentSpeed)
		end
	end))
end

local SyncBroadcast = RemotesSync:FindFirstChild("SyncBroadcast")
if SyncBroadcast and SyncBroadcast:IsA("RemoteEvent") then
	TrackGlobalConnection(SyncBroadcast.OnClientEvent:Connect(function(payload)
		if not payload or not payload.leaderUserId then return end
		if currentLeaderUserId and payload.leaderUserId == currentLeaderUserId then
			if payload.animationName ~= nil then
				if payload.animationName == "" then clearActive()
				else setActiveByName(payload.animationName) end
			end
			if payload.speed ~= nil then
				currentSpeed = math.clamp(payload.speed, MIN_SPEED, MAX_SPEED)
				UpdateSliderUI(currentSpeed)
			end
		end
	end))
end

StopButton.MouseButton1Click:Connect(function()
	if DanceActivated then
		StopAnimationRemote:FireServer()
		clearActive()
	end
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- FAVORITOS
-- ════════════════════════════════════════════════════════════════════════════════

local FAV_ICON   = "rbxassetid://75212439359134"
local NOFAV_ICON = "rbxassetid://72553305447429"
local FavLocks   = {}

local function ApplyFavBtnState(btn, isFav)
	if not btn then return end
	btn.Image             = isFav and FAV_ICON or NOFAV_ICON
	btn.ImageColor3       = THEME_CONFIG.accent
	btn.ImageTransparency = isFav and 0 or THEME_CONFIG.lightAlpha
end

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

local function ShrinkAndDestroy(card)
	if not (card and card.Parent) then return end
	CleanupCard(card)
	Tween(card, 0.2, {BackgroundTransparency = 0.8})
	local sh = Tween(card, 0.2, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if sh then
		sh.Completed:Connect(function()
			if card and card.Parent then card:Destroy() end
		end)
	elseif card and card.Parent then
		card:Destroy()
	end
end

local function RemoveCardFromScroll(sf, id, animate)
	for _, child in ipairs(sf:GetChildren()) do
		if child:GetAttribute("ID") == id and child:GetAttribute("Entry") then
			if child == ActiveCard then ActiveCard = nil end
			if animate then ShrinkAndDestroy(child)
			else CleanupCard(child); child:Destroy() end
		end
	end
end

local function ToggleFavorite(id, nombre)
	if FavLocks[id] then return end
	FavLocks[id] = true
	local wasFav  = EstaEnFavoritos(id)
	local nextFav = not wasFav

	if nextFav then
		table.insert(EmotesFavs, id)
	else
		local idx = table.find(EmotesFavs, id)
		if idx then table.remove(EmotesFavs, idx) end
	end
	SyncFavAcrossTabs(id, nextFav)

	if not nextFav then
		RemoveCardFromScroll(ScrollFavs, id, TabActual == "FAVORITOS")
		if #EmotesFavs == 0 and TabActual == "FAVORITOS" then
			MostrarEmptyMessage(true, "Sin favoritos\nToca el ícono en cualquier baile")
		end
	end

	task.spawn(function()
		local ok, status = pcall(function() return AnadirFav:InvokeServer(id) end)
		local serverFav
		if ok and status == "Anadido"   then serverFav = true  end
		if ok and status == "Eliminada" then serverFav = false end

		if not ok then
			-- Revertir cambio local
			if nextFav then
				local idx = table.find(EmotesFavs, id)
				if idx then table.remove(EmotesFavs, idx) end
			else
				table.insert(EmotesFavs, id)
			end
			SyncFavAcrossTabs(id, wasFav)
			NotificationSystem:Error("Error", "Sin conexión", 2)
		elseif serverFav ~= nil and serverFav ~= nextFav then
			-- El servidor discrepa: sincronizar con server
			if serverFav then
				if not table.find(EmotesFavs, id) then table.insert(EmotesFavs, id) end
			else
				local idx = table.find(EmotesFavs, id)
				if idx then table.remove(EmotesFavs, idx) end
			end
			SyncFavAcrossTabs(id, serverFav)
		else
			NotificationSystem:Success("Favorito", nombre .. (nextFav and " añadido" or " quitado"), 2)
		end
		FavLocks[id] = nil
	end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- CREAR TARJETA
-- ════════════════════════════════════════════════════════════════════════════════

local function CrearTarjeta(nombre, id, orden, ocultarFav, targetScroll)
	local esFavorito = (not ocultarFav) and EstaEnFavoritos(id)
	local cardHeight = GetCardHeight()

	local card = Instance.new("TextButton")
	card.Name                   = "Card_" .. id
	card.Size                   = UDim2.new(1, 0, 0, cardHeight)
	card.BackgroundColor3       = THEME_CONFIG.card
	card.BackgroundTransparency = 0
	card.BorderSizePixel        = 0
	card.LayoutOrder            = orden
	card.Text                   = ""
	card.AutoButtonColor        = false
	card:SetAttribute("Entry",      true)
	card:SetAttribute("ID",         id)
	card:SetAttribute("Name",       nombre)
	card:SetAttribute("IsFavorite", esFavorito)
	card.Parent = targetScroll or ActiveScroll
	CreateCorner(card, IsMobile and 6 or 8)

	local activeOverlay = Instance.new("Frame")
	activeOverlay.Name                   = "ActiveOverlay"
	activeOverlay.Size                   = UDim2.new(1, 0, 1, 0)
	activeOverlay.BackgroundColor3       = THEME_CONFIG.accent
	activeOverlay.BackgroundTransparency = 1
	activeOverlay.BorderSizePixel        = 0
	activeOverlay.ZIndex                 = 2
	activeOverlay.Parent                 = card
	CreateCorner(activeOverlay, IsMobile and 5 or 8)

	local activeBorder = Instance.new("UIStroke")
	activeBorder.Name         = "ActiveBorder"
	activeBorder.Color        = THEME_CONFIG.accent
	activeBorder.Thickness    = 2
	activeBorder.Transparency = 1
	activeBorder.Parent       = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                   = "NameLabel"
	nameLabel.Size                   = UDim2.new(1, IsMobile and -30 or -40, 1, 0)
	nameLabel.Position               = UDim2.new(0, IsMobile and 8 or 12, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font                   = Enum.Font.GothamBold
	nameLabel.Text                   = nombre
	nameLabel.TextColor3             = THEME_CONFIG.text
	nameLabel.TextSize               = IsMobile and 13 or 16
	nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
	nameLabel.TextTruncate           = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex                 = 3
	nameLabel.Parent                 = card

	local favContainer = Instance.new("Frame")
	favContainer.Name                   = "FavContainer"
	favContainer.Size                   = UDim2.new(0, IsMobile and 22 or 26, 0, IsMobile and 22 or 26)
	favContainer.Position               = UDim2.new(1, IsMobile and -10 or -12, 0.5, 0)
	favContainer.AnchorPoint            = Vector2.new(1, 0.5)
	favContainer.BackgroundTransparency = 1
	favContainer.ZIndex                 = 4
	favContainer.Parent                 = card

	local favBtn = Instance.new("ImageButton")
	favBtn.Name                   = "FavBtn"
	favBtn.Size                   = UDim2.new(1, 0, 1, 0)
	favBtn.BackgroundTransparency = 1
	favBtn.ZIndex                 = 5
	favBtn.Parent                 = favContainer
	ApplyFavBtnState(favBtn, esFavorito)

	if ocultarFav then
		favContainer.Visible = false
		nameLabel.Size = UDim2.new(1, IsMobile and -8 or -12, 1, 0)
	end

	local isProcessingClick = false

	TrackConnection(card, card.MouseEnter:Connect(function()
		Tween(card, 0.07, {BackgroundColor3 = THEME_CONFIG.elevated}, Enum.EasingStyle.Quad)
	end))
	TrackConnection(card, card.MouseLeave:Connect(function()
		Tween(card, 0.07, {BackgroundColor3 = THEME_CONFIG.card}, Enum.EasingStyle.Quad)
	end))

	TrackConnection(card, card.MouseButton1Click:Connect(function()
		if isProcessingClick or IsSynced then return end
		isProcessingClick = true
		if ActiveCard and ActiveCard.Parent and ActiveCard ~= card then
			RemoverEfectoActivo(ActiveCard)
		end
		DanceActivated = nombre
		ActiveCard     = card
		PlayAnimationRemote:FireServer("playAnim", nombre, currentSpeed)
		AplicarEfectoActivo(card)
		ShowStopButton(true)
		task.delay(0.1, function() isProcessingClick = false end)
	end))

	TrackConnection(card, favBtn.MouseButton1Click:Connect(function()
		ToggleFavorite(id, nombre)
	end))

	return card
end

-- ════════════════════════════════════════════════════════════════════════════════
-- CARGAR CONTENIDO
-- FIX #5: Eliminado el caché de filtro (PosesFilter/DancesFilter).
-- Siempre recarga para que cambiar de tab y volver funcione correctamente
-- y ActiveEmpty se asigne bien en todos los flujos.
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
		if ActiveCard and ActiveCard.Parent and ActiveCard ~= card then
			RemoverEfectoActivo(ActiveCard)
		end
		ActiveCard = card
		AplicarEfectoActivo(card)
	end
end

local function CargarPoses(filtro)
	filtro = (filtro or ""):lower()
	LimpiarScroll(ScrollPoses)
	local orden, hayVisibles = 1, false
	for _, v in ipairs(Modulo.Emotes or {}) do
		if filtro == "" or v.Nombre:lower():find(filtro, 1, true) then
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
	LimpiarScroll(ScrollDances)
	local orden = 1
	for _, v in ipairs(Modulo.Lista) do
		if filtro == "" or v.Nombre:lower():find(filtro, 1, true) then
			CrearTarjeta(v.Nombre, v.ID, orden, nil, ScrollDances)
			orden = orden + 1
		end
	end
	RestaurarBaileActivo()
end

local function CargarFavoritos(filtro)
	LimpiarScroll(ScrollFavs)
	if #EmotesFavs == 0 then
		MostrarEmptyMessage(true, "Sin favoritos\nToca el ícono en cualquier baile")
		return
	end
	filtro = (filtro or ""):lower()
	local orden, hayVisibles = 1, false
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
-- FIX #6: Orden correcto — primero actualizar estado (TabActual),
-- luego ShowTab (que asigna ActiveScroll y ActiveEmpty), luego cargar.
-- ════════════════════════════════════════════════════════════════════════════════

subTabs.onSwitch = function(tabId)
	local tabAnterior = TabActual   -- guardar ANTES de pisar
	TabActual = tabId
	ShowTab(tabAnterior, tabId)     -- pasa el anterior para ocultarlo correctamente
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
	if visible == emotesPanelOpen then return end
	emotesPanelOpen = visible
	local posicionFinal = IsMobile
		and UDim2.new(0, Config.Movil_MargenIzquierdo, 0.5, Config.Movil_OffsetVertical)
		or  UDim2.new(0, Config.PC_MargenIzquierdo,    0.5, Config.PC_OffsetVertical)
	local posicionOculta = IsMobile
		and UDim2.new(0, -Config.Movil_Ancho, 0.5, Config.Movil_OffsetVertical)
		or  UDim2.new(0, -Config.PC_Ancho,    0.5, Config.PC_OffsetVertical)
	if visible then
		Tween(MainFrame, 0.3,  {Position = posicionFinal},  Enum.EasingStyle.Back)
	else
		StopDrag()
		Tween(MainFrame, 0.25, {Position = posicionOculta}, Enum.EasingStyle.Quint)
	end
end

ToggleBtn.MouseButton1Click:Connect(function()
	ToggleGUI(not emotesPanelOpen)
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- LIMPIEZA
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
	pcall(function() ContentProvider:PreloadAsync(preloadList) end)
end)

local ok, favs = pcall(function() return ObtenerFavs:InvokeServer() end)
EmotesFavs = (ok and favs) or {}
CargarPoses()

-- ════════════════════════════════════════════════════════════════════════════════
-- GLOBAL
-- ════════════════════════════════════════════════════════════════════════════════

_G.OpenEmotesUI  = function() ToggleGUI(true)  end
_G.CloseEmotesUI = function() ToggleGUI(false) end