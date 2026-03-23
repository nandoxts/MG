--[[ Music Dashboard - Professional 
	by ignxts- Nando
	Restructured: HOME / LIBRARY tabs layout
	Optimized: locals grouped into tables (Luau 200 register limit)
]]

-- ════════════════════════════════════════════════════════════════
-- SERVICES
-- ════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")

-- ════════════════════════════════════════════════════════════════
-- MODULES
-- ════════════════════════════════════════════════════════════════
local Modules = {
	ModalManager = require(ReplicatedStorage:WaitForChild("Modal"):WaitForChild("ModalManager")),
	GlobalModalManager = require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("GlobalModalManager")),
	Notify = require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("NotificationSystem"):WaitForChild("NotificationSystem")),
	UI = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("UI")),
	SearchModern = require(ReplicatedStorage:WaitForChild("UIComponents"):WaitForChild("SearchModern")),
	ModernScrollbar = require(ReplicatedStorage:WaitForChild("UIComponents"):WaitForChild("ModernScrollbar")),
	THEME = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThemeConfig")),
}

local THEME = Modules.THEME

-- ════════════════════════════════════════════════════════════════
-- INSTANCE HELPERS
-- ════════════════════════════════════════════════════════════════
local function make(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then inst[k] = v end
	end
	if children then
		for _, child in ipairs(children) do child.Parent = inst end
	end
	if props.Parent then inst.Parent = props.Parent end
	return inst
end

local function makeLabel(props)
	return make("TextLabel", {
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Font = props.font or Enum.Font.Gotham, TextSize = props.size or 13,
		TextColor3 = props.color or THEME.text or Color3.new(1,1,1),
		TextXAlignment = props.alignX or Enum.TextXAlignment.Left,
		TextTruncate = props.truncate or Enum.TextTruncate.None,
		Text = props.text or "", Size = props.dim or UDim2.new(1, 0, 0, 20),
		Position = props.pos or UDim2.new(0, 0, 0, 0), ZIndex = props.z or 102,
		Visible = props.visible ~= false, Name = props.name or "Label",
		TextWrapped = props.wrap or false, Parent = props.parent,
	})
end

local function makeBtn(props)
	local btn = make("TextButton", {
		Size = props.dim or UDim2.new(0, 80, 0, 30),
		Position = props.pos or UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = props.bg or THEME.elevated,
		Text = props.text or "", TextColor3 = props.textColor or Color3.new(1, 1, 1),
		Font = props.font or Enum.Font.GothamBold, TextSize = props.textSize or 13,
		BorderSizePixel = 0, ZIndex = props.z or 103, Name = props.name or "Button",
		Parent = props.parent,
	})
	if props.round then Modules.UI.rounded(btn, props.round) end
	return btn
end

local function makeFrame(props)
	return make("Frame", {
		Size = props.dim or UDim2.new(1, 0, 1, 0),
		Position = props.pos or UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = props.bg or THEME.card,
		BackgroundTransparency = props.bgT or 1, BorderSizePixel = 0,
		ZIndex = props.z or 100, ClipsDescendants = props.clip or false,
		Name = props.name or "Frame", Parent = props.parent,
	})
end

local function makeImage(props)
	return make("ImageLabel", {
		Size = props.dim or UDim2.new(0, 40, 0, 40),
		Position = props.pos or UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = props.bgT or 1,
		BackgroundColor3 = props.bg or THEME.card,
		Image = props.image or "", ImageColor3 = props.imageColor or Color3.new(1, 1, 1),
		ImageTransparency = props.imageT or 0, ScaleType = props.scale or Enum.ScaleType.Crop,
		BorderSizePixel = 0, ZIndex = props.z or 103, Visible = props.visible ~= false,
		Name = props.name or "Image", Parent = props.parent,
	})
end

local function makeScrollColumn(parent, offsetY, paddingOpts, theme)
	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(1, paddingOpts.sizeXOff or -8, 1, -(offsetY + (paddingOpts.bottomOff or 8))),
		Position = UDim2.new(0, paddingOpts.posX or 4, 0, offsetY),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0), ClipsDescendants = true, ZIndex = 101,
		Parent = parent,
	})
	Modules.ModernScrollbar.setup(scroll, parent, theme, {transparency = 0})
	if paddingOpts.padding then
		make("UIPadding", {
			PaddingLeft = UDim.new(0, paddingOpts.padding),
			PaddingRight = UDim.new(0, paddingOpts.padding),
			PaddingTop = UDim.new(0, paddingOpts.paddingTop or paddingOpts.padding),
			PaddingBottom = UDim.new(0, paddingOpts.padding), Parent = scroll,
		})
	end
	local layout = make("UIListLayout", {
		Padding = UDim.new(0, paddingOpts.gap or 4),
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll,
	})
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
	end)
	return scroll, layout
end

local function makeCanvas(parent, corner, z)
	local cv = Instance.new("CanvasGroup")
	cv.Name = "Canvas"; cv.Size = UDim2.new(1, 0, 1, 0)
	cv.BackgroundTransparency = 1; cv.BorderSizePixel = 0
	cv.GroupTransparency = 0; cv.ZIndex = z or 103; cv.Parent = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, corner or 8); c.Parent = cv
	return cv
end

local function tw(obj, duration, props)
	TweenService:Create(obj, TweenInfo.new(duration), props):Play()
end

local function addHover(btn, hoverColor, defaultColor, defaultTransparency)
	btn.MouseEnter:Connect(function() tw(btn, 0.15, {BackgroundColor3 = hoverColor, BackgroundTransparency = 0}) end)
	btn.MouseLeave:Connect(function() tw(btn, 0.15, {BackgroundColor3 = defaultColor, BackgroundTransparency = defaultTransparency or 0}) end)
end

-- ════════════════════════════════════════════════════════════════
-- RESPONSE CODES
-- ════════════════════════════════════════════════════════════════
local ResponseCodes = {
	SUCCESS = "SUCCESS", ERROR_INVALID_ID = "ERROR_INVALID_ID",
	ERROR_BLACKLISTED = "ERROR_BLACKLISTED", ERROR_DUPLICATE = "ERROR_DUPLICATE",
	ERROR_NOT_FOUND = "ERROR_NOT_FOUND", ERROR_NOT_AUDIO = "ERROR_NOT_AUDIO",
	ERROR_NOT_AUTHORIZED = "ERROR_NOT_AUTHORIZED", ERROR_QUEUE_FULL = "ERROR_QUEUE_FULL",
	ERROR_PERMISSION = "ERROR_PERMISSION", ERROR_UNKNOWN = "ERROR_UNKNOWN",
}

local ResponseMessages = {
	[ResponseCodes.SUCCESS] = {type = "success", title = "Éxito"},
	[ResponseCodes.ERROR_INVALID_ID] = {type = "error", title = "ID Inválido"},
	[ResponseCodes.ERROR_BLACKLISTED] = {type = "error", title = "Audio Bloqueado"},
	[ResponseCodes.ERROR_DUPLICATE] = {type = "warning", title = "Duplicado"},
	[ResponseCodes.ERROR_NOT_FOUND] = {type = "error", title = "No Encontrado"},
	[ResponseCodes.ERROR_NOT_AUDIO] = {type = "error", title = "Tipo Incorrecto"},
	[ResponseCodes.ERROR_NOT_AUTHORIZED] = {type = "error", title = "No Autorizado"},
	[ResponseCodes.ERROR_QUEUE_FULL] = {type = "warning", title = "Cola Llena"},
	[ResponseCodes.ERROR_PERMISSION] = {type = "error", title = "Sin Permiso"},
	[ResponseCodes.ERROR_UNKNOWN] = {type = "error", title = "Error"},
}

-- ════════════════════════════════════════════════════════════════
-- CONFIG (grouped into table)
-- ════════════════════════════════════════════════════════════════
local player = Players.LocalPlayer
local MusicSystemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MusicSystemConfig"))
local isAdmin = MusicSystemConfig:IsAdmin(player) and true

local CFG = {
	R_PANEL = 12, R_CTRL = 10,
	ENABLE_BLUR = true, BLUR_SIZE = 14,
	CARD_HEIGHT = 54, CARD_PADDING = 6,
	VISIBLE_BUFFER = 3, BATCH_SIZE = 15, MAX_POOL_SIZE = 25,
	MAX_QUEUE_POOL = 30,
	SCROLL_DEBOUNCE = 0.03,
	PROGRESS_RATE = 0.1,
	UPDATE_THROTTLE = 0.15,
}

local ICONS = {
	PLAY_ADD = Modules.UI.ICONS.PLAY_ADD,
	CHECK    = Modules.UI.ICONS.CHECK,
	DELETE   = Modules.UI.ICONS.DELETE,
	LOADING  = Modules.UI.ICONS.LOADING,
	SKIP     = Modules.UI.ICONS.SKIP,
	VOL_DOWN = "rbxassetid://118993192034241",
	VOL_UP   = "rbxassetid://114456072508401",
}

local VISUALIZER = {
	BAR_COUNT = 40, BAR_WIDTH = 8, BAR_GAP = 2,
	BAR_MIN_H = 2, BAR_MAX_H = 50,
	COLOR_LOW = THEME.dim,
	COLOR_HIGH = THEME.accent,
}

-- ════════════════════════════════════════════════════════════════
-- STATE (single table — S)
-- ════════════════════════════════════════════════════════════════
local S = {
	playQueue = {}, currentSong = nil,
	allDJs = {}, selectedDJ = nil, selectedDJInfo = nil,
	currentSoundObject = nil, progressConnection = nil, visualizerConnection = nil,
	isAddingToQueue = false, loadingDotsThread = nil, loadingTween = nil,
	cardPool = {}, cardsIndex = {},
	selectedDJCard = nil, currentHeaderCover = "",
	activeTab = "Home",
	pendingCardSongIds = {},
	queueCardPool = {}, activeQueueCards = {},
	activeEffectThreads = {},
	scrollDebounceThread = nil,
	queueEmptyLabel = nil,
	avatarCache = {},
	scrollConnection = nil,
	searchDebounce = nil,
	progressTween = nil, progressAccum = 0,
	lastUpdateTime = 0, pendingUpdate = nil,
	lastSkipTime = 0,
	muteCheckAccum = 0, lastMuteState = false,
	visualizerBars = {},
	currentVolume = 0,
	isDraggingVolume = false,
	volumeDragInput = nil,
}

local virtualScrollState = {
	totalSongs = 0, songData = {}, visibleCards = {},
	firstVisibleIndex = 1, lastVisibleIndex = 1,
	isSearching = false, searchQuery = "", searchResults = {},
	pendingRequests = {},
}

-- ════════════════════════════════════════════════════════════════
-- UI ELEMENT REFS (single table — E, populated during build)
-- ════════════════════════════════════════════════════════════════
local E = {}

-- ════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════
local function isValidAudioId(text)
	if not text or text == "" then return false end
	if not text:match("^%d+$") then return false end
	return #text >= 6 and #text <= 19
end

local function getRemote(name)
	local RemotesGlobal = ReplicatedStorage:WaitForChild("RemotesGlobal", 10)
	if not RemotesGlobal then return end
	local remoteMap = {
		NextSong = "MusicPlayback", PlaySong = "MusicPlayback", PauseSong = "MusicPlayback",
		StopSong = "MusicPlayback", ChangeVolume = "MusicPlayback",
		AddToQueue = "MusicQueue", AddToQueueResponse = "MusicQueue",
		RemoveFromQueue = "MusicQueue", RemoveFromQueueResponse = "MusicQueue",
		ClearQueue = "MusicQueue", ClearQueueResponse = "MusicQueue",
		UpdateUI = "UI", GetDJs = "MusicLibrary", GetSongsByDJ = "MusicLibrary",
		GetSongRange = "MusicLibrary", SearchSongs = "MusicLibrary",
		GetSongMetadata = "MusicLibrary",
	}
	local folder = RemotesGlobal:FindFirstChild(remoteMap[name] or "MusicLibrary")
	return folder and folder:FindFirstChild(name)
end

local function formatTime(sec)
	return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

local function showNotification(response)
	local cfg = ResponseMessages[response.code] or ResponseMessages[ResponseCodes.ERROR_UNKNOWN]
	local msg = response.message or "Operación completada"
	if response.data and response.data.songName then msg = msg .. ": " .. response.data.songName end
	local fn = ({success = Modules.Notify.Success, warning = Modules.Notify.Warning, error = Modules.Notify.Error})[cfg.type] or Modules.Notify.Info
	fn(Modules.Notify, cfg.title, msg, cfg.type == "error" and 4 or 3)
end

local function isInQueue(songId)
	for _, song in ipairs(S.playQueue) do
		if song.id == songId then return true end
	end
	return false
end

local function isMusicMuted() return _G.MusicMutedState or false end

-- ════════════════════════════════════════════════════════════════
-- REMOTES
-- ════════════════════════════════════════════════════════════════
local R = {}
do
	local names = {
		"NextSong", "PlaySong", "StopSong", "AddToQueue", "AddToQueueResponse",
		"RemoveFromQueue", "RemoveFromQueueResponse", "ClearQueue", "ClearQueueResponse",
		"UpdateUI", "GetDJs", "GetSongsByDJ", "GetSongRange", "SearchSongs",
		"GetSongMetadata", "ChangeVolume",
	}
	local shorts = {
		NextSong = "Next", PlaySong = "Play", StopSong = "Stop",
		AddToQueue = "Add", AddToQueueResponse = "AddResponse",
		RemoveFromQueue = "Remove", RemoveFromQueueResponse = "RemoveResponse",
		ClearQueue = "Clear", ClearQueueResponse = "ClearResponse",
		UpdateUI = "Update",
	}
	for _, name in ipairs(names) do
		R[shorts[name] or name] = getRemote(name)
	end
end

-- ════════════════════════════════════════════════════════════════
-- ROOT GUI
-- ════════════════════════════════════════════════════════════════
local screenGui = make("ScreenGui", {
	Name = "MusicDashboardUI", ResetOnSpawn = false,
	IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

task.wait(0.5)
local mob = UserInputService.TouchEnabled

-- ════════════════════════════════════════════════════════════════
-- LAYOUT (grouped into table)
-- ════════════════════════════════════════════════════════════════
local LAY = {
	PANEL_W = mob and THEME.panelWidth or math.max(THEME.panelWidth, 1100),
	PANEL_H = mob and THEME.panelHeight or math.max(THEME.panelHeight, 620),
	TAB_BAR_H = 48, COL_HEADER_H = 36,
	HOME_LEFT_W = 0.52, HOME_RIGHT_W = 0.48,
	LIB_LEFT_W = 0.22, LIB_RIGHT_W = 0.78,
	COVER_SIZE = mob and 140 or 180,
	VIZ_H = mob and 40 or 50,
}

-- ════════════════════════════════════════════════════════════════
-- MODAL
-- ════════════════════════════════════════════════════════════════
local modal = Modules.ModalManager.new({
	screenGui = screenGui, panelName = "MusicDashboard",
	panelWidth = LAY.PANEL_W, panelHeight = LAY.PANEL_H,
	cornerRadius = CFG.R_PANEL, enableBlur = CFG.ENABLE_BLUR, blurSize = CFG.BLUR_SIZE,
	isMobile = mob,
	onClose = function()
		if S.progressConnection then S.progressConnection:Disconnect(); S.progressConnection = nil end
		if S.visualizerConnection then S.visualizerConnection:Disconnect(); S.visualizerConnection = nil end
	end,
})

local canvas = modal:getCanvas()

-- ════════════════════════════════════════════════════════════════
-- TOP TAB BAR
-- ════════════════════════════════════════════════════════════════
do
	local topBar = makeFrame({
		dim = UDim2.new(1, 0, 0, LAY.TAB_BAR_H), bg = THEME.bg, bgT = 0,
		z = 120, clip = true, name = "TopBar", parent = canvas,
	})
	make("UIGradient", {
		Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, THEME.card),
			ColorSequenceKeypoint.new(1, THEME.bg),
		}, Rotation = 90, Parent = topBar,
	})
	makeFrame({dim = UDim2.new(1, 0, 0, 1), pos = UDim2.new(0, 0, 1, -1), bg = THEME.stroke, bgT = 0.5, z = 121, parent = topBar})
	makeLabel({text = "MUSICA", font = Enum.Font.GothamBlack, size = 18, dim = UDim2.new(0, 200, 1, 0), pos = UDim2.new(0, 20, 0, 0), color = THEME.text, z = 122, parent = topBar})

	local tabContainer = makeFrame({dim = UDim2.new(0, 220, 0, 34), pos = UDim2.new(0.5, -110, 0.5, -17), bg = THEME.card, bgT = 0, z = 122, clip = true, name = "TabContainer", parent = topBar})
	Modules.UI.rounded(tabContainer, 17)
	make("UIStroke", {Color = THEME.stroke, Thickness = 1, Transparency = 0.25, Parent = tabContainer})

	E.tabIndicator = makeFrame({
		dim = UDim2.new(0.5, -4, 1, -4),
		pos = UDim2.new(0, 2, 0, 2),
		bg = THEME.accent,
		bgT = 0,
		z = 123,
		name = "TabIndicator",
		parent = tabContainer,
	})
	Modules.UI.rounded(E.tabIndicator, 14)

	E.tabHome = makeBtn({dim = UDim2.new(0.5, 0, 1, 0), pos = UDim2.new(0, 0, 0, 0), bg = THEME.card, text = "Inicio", textSize = 15, font = Enum.Font.GothamBold, z = 124, name = "TabHome", parent = tabContainer})
	E.tabHome.BackgroundTransparency = 1

	E.tabLibrary = makeBtn({dim = UDim2.new(0.5, 0, 1, 0), pos = UDim2.new(0.5, 0, 0, 0), bg = THEME.card, text = "Biblioteca", textSize = 15, font = Enum.Font.GothamBold, textColor = THEME.muted, z = 124, name = "TabLibrary", parent = tabContainer})
	E.tabLibrary.BackgroundTransparency = 1

	local closeBtn, _ = Modules.UI.outlinedCircleBtn(topBar, {
		size = 32, icon = "", theme = THEME, zIndex = 123,
		position = UDim2.new(1, -48, 0.5, -16), name = "CloseBtn",
	})
	closeBtn.Text = "×"; closeBtn.TextSize = 20; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextColor3 = THEME.dim
	local closeBtnStroke = closeBtn:FindFirstChildWhichIsA("UIStroke")
	closeBtn.MouseEnter:Connect(function()
		tw(closeBtn, 0.15, {TextColor3 = THEME.danger})
		if closeBtnStroke then tw(closeBtnStroke, 0.15, {Color = THEME.danger}) end
	end)
	closeBtn.MouseLeave:Connect(function()
		tw(closeBtn, 0.15, {TextColor3 = THEME.dim})
		if closeBtnStroke then tw(closeBtnStroke, 0.15, {Color = THEME.stroke}) end
	end)
	closeBtn.MouseButton1Click:Connect(function() Modules.GlobalModalManager:closeModal("Music") end)
end

-- ════════════════════════════════════════════════════════════════
-- CONTENT AREA
-- ════════════════════════════════════════════════════════════════
local contentArea = makeFrame({dim = UDim2.new(1, 0, 1, -LAY.TAB_BAR_H), pos = UDim2.new(0, 0, 0, LAY.TAB_BAR_H), z = 100, clip = true, name = "ContentArea", parent = canvas})

-- ══════════════════════════════════════════════════════════════════
--  HOME TAB
-- ══════════════════════════════════════════════════════════════════
E.homeContent = makeFrame({dim = UDim2.new(1, 0, 1, 0), z = 100, clip = true, name = "HomeContent", parent = contentArea})

-- ═══ HOME LEFT: Now Playing ═══
do
	local homeLeft = makeFrame({dim = UDim2.new(LAY.HOME_LEFT_W, 0, 1, 0), bg = THEME.bg, bgT = THEME.lightAlpha, z = 100, clip = true, name = "HomeLeft", parent = E.homeContent})
	E.homeBackgroundCover = makeImage({
		dim = UDim2.new(1, 0, 1, 0),
		pos = UDim2.new(0, 0, 0, 0),
		image = "",
		scale = Enum.ScaleType.Crop,
		imageT = 0,
		z = 100,
		name = "HomeBackgroundCover",
		parent = homeLeft,
	})
	E.homeBackgroundCover.Visible = false

	E.homeBackgroundOverlay = makeFrame({
		dim = UDim2.new(1, 0, 1, 0),
		pos = UDim2.new(0, 0, 0, 0),
		bg = THEME.bg,
		bgT = 0.5,
		z = 101,
		name = "HomeBackgroundOverlay",
		parent = homeLeft,
	})

	makeFrame({dim = UDim2.new(0, 1, 1, -20), pos = UDim2.new(1, 0, 0, 10), bg = THEME.stroke, bgT = 0.5, z = 101, parent = homeLeft})

	-- ScrollingFrame para todo el contenido del Now Playing
	local nowPlayingScroll = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0), ClipsDescendants = true, ZIndex = 102,
		Parent = homeLeft,
	})
	makeLabel({text = "SONANDO", font = Enum.Font.GothamBlack, size = 14, dim = UDim2.new(1, -24, 0, 20), pos = UDim2.new(0, 16, 0, 12), color = THEME.dim, z = 102, parent = nowPlayingScroll})

	-- Album Cover
	local coverContainer = makeFrame({dim = UDim2.new(1, 0, 0, LAY.COVER_SIZE + 16), pos = UDim2.new(0, 0, 0, 38), z = 102, parent = nowPlayingScroll})
	E.miniCover = makeImage({dim = UDim2.new(0, LAY.COVER_SIZE, 0, LAY.COVER_SIZE), pos = UDim2.new(0.5, -LAY.COVER_SIZE/2, 0, 4), z = 103, name = "MiniCover", parent = coverContainer})
	E.miniCover.ClipsDescendants = true
	Modules.UI.rounded(E.miniCover, 10)
	make("UIStroke", {Color = THEME.accent, Thickness = 1.5, Transparency = 0.4, Parent = E.miniCover})

	-- Song Info
	local infoY = 38 + LAY.COVER_SIZE + 20
	E.songTitle = makeLabel({dim = UDim2.new(1, -32, 0, 24), pos = UDim2.new(0, 16, 0, infoY), text = "Sin cancion", font = Enum.Font.GothamBold, size = mob and 16 or 18, alignX = Enum.TextXAlignment.Center, truncate = Enum.TextTruncate.AtEnd, z = 103, name = "SongTitle", parent = nowPlayingScroll})
	E.headerDJName = makeLabel({dim = UDim2.new(1, -32, 0, 18), pos = UDim2.new(0, 16, 0, infoY + 28), color = THEME.dim, font = Enum.Font.GothamBold, size = mob and 12 or 14, alignX = Enum.TextXAlignment.Center, truncate = Enum.TextTruncate.AtEnd, z = 103, name = "DJName", parent = nowPlayingScroll})

	-- Visualizer
	local vizY = infoY + 56
	local vizContainer = makeFrame({dim = UDim2.new(1, -32, 0, LAY.VIZ_H), pos = UDim2.new(0, 16, 0, vizY), z = 102, clip = true, name = "VisualizerContainer", parent = nowPlayingScroll})
	local totalVizW = VISUALIZER.BAR_COUNT * (VISUALIZER.BAR_WIDTH + VISUALIZER.BAR_GAP)
	for i = 1, VISUALIZER.BAR_COUNT do
		local barX = (i - 1) * (VISUALIZER.BAR_WIDTH + VISUALIZER.BAR_GAP)
		local bar = makeFrame({dim = UDim2.new(0, VISUALIZER.BAR_WIDTH, 0, VISUALIZER.BAR_MIN_H), pos = UDim2.new(0.5, barX - math.floor(totalVizW / 2), 1, -VISUALIZER.BAR_MIN_H), bg = VISUALIZER.COLOR_LOW, bgT = 0.5, z = 103, name = "Bar"..i, parent = vizContainer})
		Modules.UI.rounded(bar, 1)
		S.visualizerBars[i] = {frame = bar, currentH = VISUALIZER.BAR_MIN_H, targetH = VISUALIZER.BAR_MIN_H, phase = math.random() * math.pi * 2, freqWeight = math.abs((i - VISUALIZER.BAR_COUNT / 2) / (VISUALIZER.BAR_COUNT / 2))}
	end

	-- Progress Bar
	local progY = vizY + LAY.VIZ_H + 8
	local progressContainer = makeFrame({dim = UDim2.new(1, -32, 0, 28), pos = UDim2.new(0, 16, 0, progY), z = 103, parent = nowPlayingScroll})
	E.currentTimeLabel = makeLabel({dim = UDim2.new(0, 44, 1, 0), text = "0:00", color = THEME.muted, font = Enum.Font.GothamBold, size = mob and 13 or 15, alignX = Enum.TextXAlignment.Right, z = 104, parent = progressContainer})
	local progressBar = makeFrame({dim = UDim2.new(1, -108, 0, mob and 6 or 10), pos = UDim2.new(0, 52, 0.5, mob and -3 or -5), bg = THEME.elevated, bgT = 0, z = 103, parent = progressContainer})
	Modules.UI.rounded(progressBar, 5)
	E.progressFill = makeFrame({dim = UDim2.new(0, 0, 1, 0), bg = THEME.accent, bgT = 0, z = 104, parent = progressBar})
	Modules.UI.rounded(E.progressFill, 5)
	E.totalTimeLabel = makeLabel({dim = UDim2.new(0, 44, 1, 0), pos = UDim2.new(1, -44, 0, 0), text = "0:00", color = THEME.muted, font = Enum.Font.GothamBold, size = mob and 13 or 15, alignX = Enum.TextXAlignment.Left, z = 104, parent = progressContainer})

	-- Volume Control
	local volY = progY + 36
	local volFrame = makeFrame({dim = UDim2.new(1, -32, 0, 40), pos = UDim2.new(0, 16, 0, volY), z = 103, name = "VolumeControl", parent = nowPlayingScroll})
	makeImage({dim = UDim2.new(0, 24, 0, 24), pos = UDim2.new(0, 8, 0.5, -12), image = ICONS.VOL_UP, z = 104, parent = volFrame})

	E.volSliderTrack = makeFrame({dim = UDim2.new(1, -120, 0, 8), pos = UDim2.new(0, 40, 0.5, -4), bg = THEME.elevated, bgT = 0, z = 104, name = "VolTrack", parent = volFrame})
	Modules.UI.rounded(E.volSliderTrack, 4)

	E.volSliderFill = makeFrame({dim = UDim2.new(1, 0, 1, 0), bg = THEME.accent, bgT = 0, z = 105, name = "VolFill", parent = E.volSliderTrack})
	Modules.UI.rounded(E.volSliderFill, 5)

	E.volSliderDot = makeFrame({dim = UDim2.new(0, 16, 0, 16), pos = UDim2.new(1, -8, 0.5, -8), bg = THEME.text, bgT = 0, z = 106, name = "VolDot", parent = E.volSliderFill})
	Modules.UI.rounded(E.volSliderDot, 8)

	E.volLabelText = makeLabel({dim = UDim2.new(0, 50, 1, 0), pos = UDim2.new(1, -58, 0, 0), text = "100%", color = THEME.text, font = Enum.Font.GothamBold, size = 14, alignX = Enum.TextXAlignment.Right, z = 104, parent = volFrame})

	E.volInput = make("TextBox", {Size = UDim2.new(0, 50, 0, 30), Position = UDim2.new(1, -58, 0.5, -15), BackgroundColor3 = THEME.elevated, Text = "", TextColor3 = THEME.text, Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0, ZIndex = 107, Visible = false, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Center, Parent = volFrame})
	Modules.UI.rounded(E.volInput, 6)

	E.volSliderBtn = makeBtn({dim = UDim2.new(1, -120, 0, 24), pos = UDim2.new(0, 40, 0.5, -12), z = 108, name = "VolSliderBtn", parent = volFrame})
	E.volSliderBtn.BackgroundTransparency = 1

	-- Controls Row (Skip + Add by ID)
	local skipY = volY + 48
	local controlsRow = makeFrame({dim = UDim2.new(1, -32, 0, 56), pos = UDim2.new(0, 16, 0, skipY), z = 102, name = "ControlsRow", parent = nowPlayingScroll})

	-- Skip (left)
	E.skipB, _ = Modules.UI.outlinedCircleBtn(controlsRow, {
		size = 48, icon = ICONS.SKIP, theme = THEME, zIndex = 103,
		position = UDim2.new(0, 0, 0.5, -24), name = "SkipBtn",
	})
	local skipStroke = E.skipB:FindFirstChildWhichIsA("UIStroke")
	E.skipB.MouseEnter:Connect(function()
		if skipStroke then tw(skipStroke, 0.15, {Color = THEME.accent}) end
	end)
	E.skipB.MouseLeave:Connect(function()
		if skipStroke then tw(skipStroke, 0.15, {Color = THEME.stroke}) end
	end)

	-- Add by ID (right of skip)
	local addIdInputFrame = makeFrame({dim = UDim2.new(1, -62, 0, 40), pos = UDim2.new(0, 56, 0.5, -20), bg = THEME.elevated, bgT = 0, z = 103, clip = true, name = "AddByIdInput", parent = controlsRow})
	Modules.UI.rounded(addIdInputFrame, 10)
	E.qiStroke = Modules.UI.stroked(addIdInputFrame, 0.4)
	E.quickInput = make("TextBox", {Size = UDim2.new(1, -46, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "ID de audio...", TextColor3 = THEME.text, PlaceholderColor3 = THEME.dim, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 104, Parent = addIdInputFrame})
	E.quickInput:GetPropertyChangedSignal("Text"):Connect(function()
		if #E.quickInput.Text > 19 then E.quickInput.Text = string.sub(E.quickInput.Text, 1, 19) end
	end)
	E.quickAddBtn, _ = Modules.UI.outlinedCircleBtn(addIdInputFrame, {
		size = 32, icon = ICONS.PLAY_ADD, theme = THEME, zIndex = 105,
		position = UDim2.new(1, -36, 0.5, -16), name = "QuickAddBtn",
	})
	E.qaStroke = E.quickAddBtn:FindFirstChildWhichIsA("UIStroke")
	E.quickAddBtnImg = E.quickAddBtn:FindFirstChild("IconImage")
	E.quickAddBtnLoading = makeImage({dim = UDim2.new(0.55, 0, 0.55, 0), pos = UDim2.new(0.225, 0, 0.225, 0), image = ICONS.LOADING, imageColor = THEME.dim, z = 107, visible = false, name = "LoadingIcon", parent = E.quickAddBtn})

	-- CanvasSize = todo el contenido + padding inferior
	nowPlayingScroll.CanvasSize = UDim2.new(0, 0, 0, skipY + 56 + 24)
	-- offset negativo para que quede DENTRO de homeLeft (que tiene ClipsDescendants=true)
	-- width=4, offset=-8 → el thumb queda en [parentW-8 .. parentW-4], 4px adentro del borde
	Modules.ModernScrollbar.setup(nowPlayingScroll, homeLeft, THEME, {transparency = 0, zIndex = 120, offset = -8})
end

-- ═══ HOME RIGHT: Queue ═══
do
	local homeRight = makeFrame({dim = UDim2.new(LAY.HOME_RIGHT_W, 0, 1, 0), pos = UDim2.new(LAY.HOME_LEFT_W, 0, 0, 0), z = 100, name = "HomeRight", parent = E.homeContent})
	local queueHeader = makeFrame({dim = UDim2.new(1, 0, 0, LAY.COL_HEADER_H), z = 101, parent = homeRight})
	makeLabel({text = "COLA", font = Enum.Font.GothamBlack, size = 20, dim = UDim2.new(1, -16, 1, 0), pos = UDim2.new(0, 12, 0, 0), color = THEME.text, z = 102, parent = queueHeader})

	if isAdmin then
		E.clearB = makeBtn({dim = UDim2.new(0, 60, 0, 24), pos = UDim2.new(1, -68, 0.5, -12), bg = THEME.warn, text = "LIMPIAR", textSize = 10, z = 103, round = 6, parent = queueHeader})
	end

	E.queueScroll = makeScrollColumn(homeRight, LAY.COL_HEADER_H + 4, {sizeXOff = -12, posX = 6, bottomOff = 8, padding = 4, paddingTop = 4, gap = 4}, THEME)
end

-- ══════════════════════════════════════════════════════════════════
--  LIBRARY TAB
-- ══════════════════════════════════════════════════════════════════
E.libraryContent = makeFrame({dim = UDim2.new(1, 0, 1, 0), z = 100, clip = true, name = "LibraryContent", parent = contentArea})
E.libraryContent.Visible = false

-- ═══ LIBRARY LEFT: Collections ═══
do
	local libLeft = makeFrame({dim = UDim2.new(LAY.LIB_LEFT_W, 0, 1, 0), bg = THEME.bg, bgT = THEME.lightAlpha, z = 100, name = "LibLeft", parent = E.libraryContent})
	makeFrame({dim = UDim2.new(0, 1, 1, -20), pos = UDim2.new(1, 0, 0, 10), bg = THEME.stroke, bgT = 0.5, z = 101, parent = libLeft})
	makeLabel({text = "LISTAS", font = Enum.Font.GothamBlack, size = 16, dim = UDim2.new(1, -16, 0, LAY.COL_HEADER_H), pos = UDim2.new(0, 12, 0, 0), color = THEME.text, z = 102, parent = libLeft})

	E.djsScroll = make("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -LAY.COL_HEADER_H - 8), Position = UDim2.new(0, 4, 0, LAY.COL_HEADER_H + 4),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0), ClipsDescendants = true, ZIndex = 101, Parent = libLeft,
	})
	Modules.ModernScrollbar.setup(E.djsScroll, libLeft, THEME, {transparency = 0})

	local djsLayout = make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = E.djsScroll})
	make("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 2), Parent = E.djsScroll})
	djsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		E.djsScroll.CanvasSize = UDim2.new(0, 0, 0, djsLayout.AbsoluteContentSize.Y + 12)
	end)
end

-- ═══ LIBRARY RIGHT: Songs ═══
do
	local libRight = makeFrame({dim = UDim2.new(LAY.LIB_RIGHT_W, 0, 1, 0), pos = UDim2.new(LAY.LIB_LEFT_W, 0, 0, 0), z = 100, clip = true, name = "LibRight", parent = E.libraryContent})
	local songsHeader = makeFrame({dim = UDim2.new(1, -20, 0, 82), pos = UDim2.new(0, 10, 0, 4), z = 101, clip = true, parent = libRight})

	E.songsTitle = makeLabel({text = "CANCIONES", font = Enum.Font.GothamBlack, size = 18, dim = UDim2.new(1, -70, 0, 28), truncate = Enum.TextTruncate.AtEnd, alignX = Enum.TextXAlignment.Left, z = 102, name = "SongsTitle", parent = songsHeader})
	E.songCountLabel = makeLabel({dim = UDim2.new(0, 65, 0, 28), pos = UDim2.new(1, -65, 0, 0), color = THEME.accent, font = Enum.Font.GothamBold, size = 12, alignX = Enum.TextXAlignment.Right, z = 102, visible = false, parent = songsHeader})

	local searchContainer
	searchContainer, E.searchInput = Modules.SearchModern.new(songsHeader, {placeholder = "Buscar...", size = UDim2.new(1, 0, 0, 36), bg = THEME.card, corner = 10, z = 102, inputName = "SearchInput"})
	searchContainer.Position = UDim2.new(0, 0, 0, 38)
	searchContainer.Size = UDim2.new(1, -2, 0, 34)
	if E.searchInput then
		E.searchInput.TextSize = 14
		E.searchInput.Font = Enum.Font.GothamBold
		E.searchInput.PlaceholderColor3 = THEME.dim
	end

	E.songsScroll = make("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -96), Position = UDim2.new(0, 10, 0, 90),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0), ClipsDescendants = true, ZIndex = 101, Parent = libRight,
	})
	Modules.ModernScrollbar.setup(E.songsScroll, libRight, THEME, {transparency = 0})

	E.songsContainer = makeFrame({name = "SongsContainer", dim = UDim2.new(1, 0, 0, 0), z = 101, parent = E.songsScroll})
	E.loadingIndicator = makeLabel({dim = UDim2.new(1, 0, 0, 40), text = "Cargando...", color = THEME.muted, size = 15, z = 102, visible = false, parent = E.songsScroll})
	E.songsPlaceholder = makeLabel({dim = UDim2.new(1, -40, 0, 80), pos = UDim2.new(0, 20, 0.4, 0), text = "Elige una lista\npara ver canciones", color = THEME.muted, size = 16, wrap = true, z = 102, alignX = Enum.TextXAlignment.Center, name = "Placeholder", parent = libRight})
end

-- ════════════════════════════════════════════════════════════════
-- TAB SWITCHING
-- ════════════════════════════════════════════════════════════════
local function switchTab(tab)
	S.activeTab = tab
	if tab == "Home" then
		E.homeContent.Visible = true; E.libraryContent.Visible = false
		if E.tabIndicator then tw(E.tabIndicator, 0.22, {Position = UDim2.new(0, 2, 0, 2)}) end
		E.tabHome.TextColor3 = THEME.text
		E.tabLibrary.TextColor3 = THEME.dim
	else
		E.homeContent.Visible = false; E.libraryContent.Visible = true
		if E.tabIndicator then tw(E.tabIndicator, 0.22, {Position = UDim2.new(0.5, 2, 0, 2)}) end
		E.tabLibrary.TextColor3 = THEME.text
		E.tabHome.TextColor3 = THEME.dim
	end
end

E.tabHome.MouseButton1Click:Connect(function() switchTab("Home") end)
E.tabLibrary.MouseButton1Click:Connect(function() switchTab("Library") end)

-- ════════════════════════════════════════════════════════════════
-- ADD BUTTON STATE MACHINE
-- ════════════════════════════════════════════════════════════════
local function setAddButtonState(state, customMessage)
	if not E.quickAddBtn or not E.quickInput or not E.qiStroke then return end
	if S.loadingDotsThread then task.cancel(S.loadingDotsThread); S.loadingDotsThread = nil end
	if S.loadingTween then S.loadingTween:Cancel(); S.loadingTween = nil end

	local states = {
		loading   = {adding = true,  bg = THEME.elevated, stroke = THEME.accent, auto = false},
		success   = {adding = false, bg = THEME.success, stroke = THEME.success, clear = true, delay = 2},
		error     = {adding = false, bg = THEME.danger, stroke = THEME.danger, clear = true, placeholder = customMessage, delay = 3},
		duplicate = {adding = false, bg = THEME.warn, stroke = THEME.warn, clear = true, placeholder = customMessage or "Ya en cola", delay = 3},
		default   = {adding = false, bg = THEME.accent, stroke = THEME.stroke, auto = true, placeholder = "ID de audio..."},
	}

	local s = states[state] or states.default
	S.isAddingToQueue = s.adding
	E.qiStroke.Color = s.stroke
	if E.qaStroke then E.qaStroke.Color = s.stroke end
	E.quickAddBtn.AutoButtonColor = s.auto ~= false

	if state == "loading" then
		E.quickAddBtnImg.Visible = false; E.quickAddBtnLoading.Visible = true
		S.loadingDotsThread = task.spawn(function()
			S.loadingTween = TweenService:Create(E.quickAddBtnLoading, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = 360})
			S.loadingTween:Play()
			while true do task.wait(0.1) end
		end)
	else
		E.quickAddBtnLoading.Visible = false; E.quickAddBtnImg.Visible = true
	end
	if s.clear then E.quickInput.Text = "" end
	if s.placeholder then E.quickInput.PlaceholderText = s.placeholder end
	if s.delay then task.delay(s.delay, function() if E.quickAddBtn and E.qiStroke then setAddButtonState("default") end end) end
end

-- ════════════════════════════════════════════════════════════════
-- QUICK ADD + RESPONSE HANDLERS
-- ════════════════════════════════════════════════════════════════
E.quickAddBtn.MouseButton1Click:Connect(function()
	if S.isAddingToQueue then return end
	local aid = E.quickInput.Text:gsub("%s+", "")
	if not isValidAudioId(aid) then
		Modules.Notify:Warning("ID no valido", "Ingresa un ID valido (6-19 digitos)", 3)
		setAddButtonState("error", "ID no valido"); return
	end
	setAddButtonState("loading")
	if R.Add then R.Add:FireServer(tonumber(aid)) end
end)

local function updatePendingCard(response, songId)
	task.defer(function()
		if not songId then return end
		S.pendingCardSongIds[songId] = nil
		for _, card in ipairs(S.cardPool) do
			if card.Visible and card:GetAttribute("SongID") == songId then
				local addBtn = card:FindFirstChild("AddButton", true)
				if not addBtn then break end
				local loadingIcon = addBtn:FindFirstChild("LoadingIcon")
				if loadingIcon then loadingIcon.Visible = false end
				local icon = addBtn:FindFirstChild("IconImage")
				if icon then icon.Visible = true end
				local abStroke = addBtn:FindFirstChildWhichIsA("UIStroke")
				if response.success or response.code == ResponseCodes.ERROR_DUPLICATE then
					if icon then icon.Image = ICONS.CHECK; icon.ImageColor3 = THEME.success end
					if abStroke then abStroke.Color = THEME.success end
				else
					if icon then icon.Image = ICONS.PLAY_ADD; icon.ImageColor3 = THEME.dim end
					if abStroke then abStroke.Color = THEME.stroke end
				end
				break
			end
		end
	end)
end

if R.AddResponse then
	R.AddResponse.OnClientEvent:Connect(function(response)
		if not response then return end
		showNotification(response)
		if response.success then setAddButtonState("success")
		elseif response.code == ResponseCodes.ERROR_DUPLICATE then setAddButtonState("duplicate", response.message)
		else setAddButtonState("error", response.message) end
		if response.data and response.data.songId then
			updatePendingCard(response, response.data.songId)
		else
			for sid in pairs(S.pendingCardSongIds) do updatePendingCard(response, sid) end
		end
	end)
end

for _, rn in ipairs({"RemoveResponse", "ClearResponse"}) do
	if R[rn] then R[rn].OnClientEvent:Connect(function(resp) if resp then showNotification(resp) end end) end
end

-- ════════════════════════════════════════════════════════════════
-- VOLUME LOGIC
-- ════════════════════════════════════════════════════════════════
local maxVolume = MusicSystemConfig.PLAYBACK.MaxVolume
local minVolume = MusicSystemConfig.PLAYBACK.MinVolume
S.currentVolume = player:GetAttribute("MusicVolume") or MusicSystemConfig.PLAYBACK.DefaultVolume

local function updateVolumeDisplay()
	local frac = math.clamp((S.currentVolume - minVolume) / (maxVolume - minVolume), 0, 1)
	if S.isDraggingVolume then
		E.volSliderFill.Size = UDim2.new(frac, 0, 1, 0)
	else
		tw(E.volSliderFill, 0.08, {Size = UDim2.new(frac, 0, 1, 0)})
	end
	if isMusicMuted() then
		E.volLabelText.Text = "MUTE"; E.volLabelText.TextColor3 = THEME.danger
	else
		E.volLabelText.Text = math.floor(S.currentVolume * 100) .. "%"; E.volLabelText.TextColor3 = THEME.text
	end
end

local function updateVolume(volume)
	S.currentVolume = math.clamp(volume, minVolume, maxVolume)
	updateVolumeDisplay()
	player:SetAttribute("MusicVolume", S.currentVolume)
	local sg = SoundService:FindFirstChild("MusicSoundGroup")
	if sg then sg.Volume = isMusicMuted() and 0 or S.currentVolume end
	if R.ChangeVolume then pcall(function() R.ChangeVolume:FireServer(S.currentVolume) end) end
end

do
	local musicSoundGroup = SoundService:FindFirstChild("MusicSoundGroup") or SoundService:WaitForChild("MusicSoundGroup", 10)
	S.lastMuteState = isMusicMuted()
	RunService.Heartbeat:Connect(function(dt)
		S.muteCheckAccum = S.muteCheckAccum + dt
		if S.muteCheckAccum >= 0.5 then
			S.muteCheckAccum = 0
			local muted = isMusicMuted()
			if muted ~= S.lastMuteState then
				S.lastMuteState = muted
				if musicSoundGroup then musicSoundGroup.Volume = muted and 0 or S.currentVolume end
				updateVolumeDisplay()
			end
		end
	end)
end

updateVolume(S.currentVolume)

local function handleMuteCheck()
	if isMusicMuted() then Modules.Notify:Info("Silenciado", "Activa el sonido para cambiar el volumen", 2); return true end
	return false
end

E.volSliderBtn.MouseButton1Click:Connect(function()
	if handleMuteCheck() then return end
	local mouse = UserInputService:GetMouseLocation()
	local trackPos = E.volSliderTrack.AbsolutePosition
	local trackSize = E.volSliderTrack.AbsoluteSize
	local frac = math.clamp((mouse.X - trackPos.X) / trackSize.X, 0, 1)
	updateVolume(minVolume + frac * (maxVolume - minVolume))
end)

local function updateVolumeFromPointer(pointerX)
	local trackPos = E.volSliderTrack.AbsolutePosition
	local trackSize = E.volSliderTrack.AbsoluteSize
	local frac = math.clamp((pointerX - trackPos.X) / trackSize.X, 0, 1)
	updateVolume(minVolume + frac * (maxVolume - minVolume))
end

local function beginVolumeDrag(input)
	if handleMuteCheck() then return end
	S.isDraggingVolume = true
	S.volumeDragInput = (input and input.UserInputType == Enum.UserInputType.Touch) and input or nil
	if E.volSliderDot then
		tw(E.volSliderDot, 0.1, {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -10, 0.5, -10)})
	end
	local x = (input and input.Position and input.Position.X) or UserInputService:GetMouseLocation().X
	updateVolumeFromPointer(x)
end

local function endVolumeDrag()
	if not S.isDraggingVolume then return end
	S.isDraggingVolume = false
	S.volumeDragInput = nil
	if E.volSliderDot then
		tw(E.volSliderDot, 0.1, {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -8, 0.5, -8)})
	end
end

E.volSliderBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		beginVolumeDrag(input)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not S.isDraggingVolume then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		updateVolumeFromPointer(input.Position.X)
	elseif input.UserInputType == Enum.UserInputType.Touch and input == S.volumeDragInput then
		updateVolumeFromPointer(input.Position.X)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not S.isDraggingVolume then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		endVolumeDrag()
	elseif input.UserInputType == Enum.UserInputType.Touch and input == S.volumeDragInput then
		endVolumeDrag()
	end
end)

E.volLabelText.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if handleMuteCheck() then return end
		E.volInput.Text = tostring(math.floor(S.currentVolume * 100))
		E.volInput.Visible = true; E.volLabelText.Visible = false; E.volInput:CaptureFocus()
	end
end)

E.volInput:GetPropertyChangedSignal("Text"):Connect(function()
	local text = E.volInput.Text:gsub("[^%d]", "")
	if #text > 3 then text = string.sub(text, 1, 3) end
	local v = tonumber(text)
	if v and v > math.floor(maxVolume * 100) then text = tostring(math.floor(maxVolume * 100)) end
	E.volInput.Text = text
end)

local function applyVolumeInput()
	local parsed = tonumber(E.volInput.Text)
	updateVolume(parsed and math.clamp(parsed, 0, math.floor(maxVolume * 100)) / 100 or S.currentVolume)
	E.volInput.Visible = false; E.volLabelText.Visible = true
end

E.volInput.FocusLost:Connect(applyVolumeInput)

-- ════════════════════════════════════════════════════════════════
-- SKIP/CLEAR LOGIC
-- ════════════════════════════════════════════════════════════════
do
	local skipProductId = 3468988018
	local skipRemote = ReplicatedStorage:WaitForChild("RemotesGlobal"):WaitForChild("MusicQueue"):WaitForChild("PurchaseSkip")
	local skipCooldown = MusicSystemConfig.LIMITS.SkipCooldown or 3

	E.skipB.MouseButton1Click:Connect(function()
		local elapsed = tick() - S.lastSkipTime
		if not isAdmin and elapsed < skipCooldown then
			Modules.Notify:Info("Espera", "Espera " .. math.ceil(skipCooldown - elapsed) .. " seg"); return
		end
		S.lastSkipTime = tick()
		if isAdmin then
			if R.Next then R.Next:FireServer(); Modules.Notify:Success("Saltar", "Cancion saltada") end
		else MarketplaceService:PromptProductPurchase(player, skipProductId) end
	end)

	if E.clearB then E.clearB.MouseButton1Click:Connect(function() if R.Clear then R.Clear:FireServer() end end) end

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
		if userId == player.UserId and productId == skipProductId and wasPurchased then
			pcall(function() skipRemote:FireServer() end)
		end
	end)

	skipRemote.OnClientEvent:Connect(function(ok, msg)
		if ok then Modules.Notify:Success("Saltar", msg or "Cancion saltada")
		else Modules.Notify:Error("Saltar", msg or "No se pudo saltar") end
	end)
end

-- ════════════════════════════════════════════════════════════════
-- QUEUE CARD POOL
-- ════════════════════════════════════════════════════════════════
local function createQueueCard()
	local card = makeFrame({dim = UDim2.new(1, 0, 0, 60), bg = THEME.card, bgT = THEME.frameAlpha, z = 101})
	card.Visible = false
	Modules.UI.rounded(card, 10)
	make("UIStroke", {Color = THEME.stroke, Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card})
	make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), Parent = card})

	local numBadge = makeFrame({dim = UDim2.new(0, 24, 0, 24), pos = UDim2.new(0, 0, 0.5, -12), bg = THEME.accent, bgT = 0, z = 102, name = "NumBadge", parent = card})
	Modules.UI.rounded(numBadge, 12)
	makeLabel({dim = UDim2.new(1, 0, 1, 0), text = "1", font = Enum.Font.GothamBold, size = 11, color = THEME.text, alignX = Enum.TextXAlignment.Center, z = 103, name = "NumLabel", parent = numBadge})

	local avatar = makeImage({dim = UDim2.new(0, 42, 0, 42), pos = UDim2.new(0, 30, 0.5, -21), bg = THEME.elevated, bgT = 0, z = 102, name = "Avatar", parent = card})
	Modules.UI.rounded(avatar, 6)

	local nameClip = makeFrame({dim = UDim2.new(1, -90, 0, 18), pos = UDim2.new(0, 80, 0, 8), z = 102, clip = true, name = "NameClip", parent = card})
	makeLabel({text = "", color = THEME.text, font = Enum.Font.GothamBold, size = 13, truncate = Enum.TextTruncate.AtEnd, z = 102, name = "NameLabel", parent = nameClip})
	makeLabel({dim = UDim2.new(1, -90, 0, 14), pos = UDim2.new(0, 80, 0, 26), text = "", color = THEME.dim, font = Enum.Font.GothamBold, size = 11, truncate = Enum.TextTruncate.AtEnd, z = 102, name = "PlaylistLabel", parent = card})
	makeLabel({dim = UDim2.new(1, -90, 0, 14), pos = UDim2.new(0, 80, 0, 40), text = "", color = THEME.dim, font = Enum.Font.GothamBold, size = 11, truncate = Enum.TextTruncate.AtEnd, z = 102, name = "RequesterLabel", parent = card})

	if isAdmin then
		local removeBtn, _ = Modules.UI.outlinedCircleBtn(card, {
			size = 28, icon = ICONS.DELETE,
			theme = {stroke = THEME.danger, dim = THEME.danger},
			zIndex = 103, position = UDim2.new(1, -32, 0.5, -14),
			name = "RemoveBtn",
		})
	end
	return card
end

local function getQueueCardFromPool()
	for _, card in ipairs(S.queueCardPool) do if not card.Visible then return card end end
	if #S.queueCardPool < CFG.MAX_QUEUE_POOL then
		local c = createQueueCard(); c.Parent = E.queueScroll; table.insert(S.queueCardPool, c); return c
	end
	return nil
end

local function releaseAllQueueCards()
	for _, card in ipairs(S.activeQueueCards) do card.Visible = false; card:SetAttribute("QueueIndex", nil) end
	S.activeQueueCards = {}
end

local function cleanupActiveEffects()
	for _, td in ipairs(S.activeEffectThreads) do if td.thread then task.cancel(td.thread) end end
	S.activeEffectThreads = {}
end

local function createActiveCardEffects(card)
	local stroke = card:FindFirstChildWhichIsA("UIStroke")
	if stroke then stroke.Color = THEME.accent; stroke.Thickness = 1.2; stroke.Transparency = 0.3 end

	local t1 = task.spawn(function()
		while card.Parent and card.Visible do
			if stroke then tw(stroke, 1, {Transparency = 0, Thickness = 1.6}) end; task.wait(1)
			if stroke then tw(stroke, 1, {Transparency = 0.5, Thickness = 1.2}) end; task.wait(1)
		end
	end)
	table.insert(S.activeEffectThreads, {thread = t1, card = card})

	local grad = card:FindFirstChild("ActiveGradient")
	if not grad then
		local gradDark = THEME.bg:Lerp(THEME.card, 0.45)
		local gradMid = THEME.bg:Lerp(THEME.accent, 0.22)
		local gradPeak = THEME.bg:Lerp(THEME.accent, 0.35)
		grad = make("UIGradient", {
			Name = "ActiveGradient",
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, gradDark),
				ColorSequenceKeypoint.new(0.3, gradMid),
				ColorSequenceKeypoint.new(0.5, gradPeak),
				ColorSequenceKeypoint.new(0.7, gradMid),
				ColorSequenceKeypoint.new(1, gradDark),
			}, Transparency = NumberSequence.new(0.3), Offset = Vector2.new(-1, 0), Parent = card,
		})
	end
	grad.Offset = Vector2.new(-1, 0)

	local t2 = task.spawn(function()
		while card.Parent and card.Visible do
			tw(grad, 2.5, {Offset = Vector2.new(1, 0)}); task.wait(2.5)
			grad.Offset = Vector2.new(-1, 0); task.wait(0.5)
		end
	end)
	table.insert(S.activeEffectThreads, {thread = t2, card = card})
end

local function drawQueue()
	cleanupActiveEffects(); releaseAllQueueCards()
	if not S.queueEmptyLabel then
		S.queueEmptyLabel = makeLabel({text = "Cola vacia", color = THEME.muted, size = 13, dim = UDim2.new(1, 0, 0, 60), wrap = true, parent = E.queueScroll})
	end
	if #S.playQueue == 0 then S.queueEmptyLabel.Visible = true; return end
	S.queueEmptyLabel.Visible = false

	for i, song in ipairs(S.playQueue) do
		local isActive = S.currentSong and song.id == S.currentSong.id
		local card = getQueueCardFromPool()
		if not card then break end
		card.LayoutOrder = i; card:SetAttribute("QueueIndex", i)
		card.BackgroundColor3 = isActive and THEME.accent or THEME.card
		card.BackgroundTransparency = isActive and THEME.subtleAlpha or THEME.frameAlpha
		card.Visible = true; table.insert(S.activeQueueCards, card)

		local stroke = card:FindFirstChildWhichIsA("UIStroke")
		if stroke then stroke.Color = isActive and THEME.accent or THEME.stroke; stroke.Transparency = isActive and 0.6 or 0.3 end
		if isActive then createActiveCardEffects(card) end

		local numBadge = card:FindFirstChild("NumBadge")
		if numBadge then
			numBadge.BackgroundColor3 = isActive and THEME.text or THEME.accent
			local numLabel = numBadge:FindFirstChild("NumLabel")
			if numLabel then numLabel.Text = tostring(i); numLabel.TextColor3 = isActive and THEME.accent or THEME.text end
		end

		local avatar = card:FindFirstChild("Avatar")
		if avatar then
			local djCover = song.djCover or (S.selectedDJInfo and S.selectedDJInfo.cover) or ""
			local userId = song.userId or song.requestedByUserId
			if djCover ~= "" then avatar.Image = djCover
			elseif userId then
				if S.avatarCache[userId] then avatar.Image = S.avatarCache[userId]
				else
					avatar.Image = ""
					task.spawn(function()
						local ok, thumb = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
						if ok then S.avatarCache[userId] = thumb; if avatar and avatar.Parent then avatar.Image = thumb end end
					end)
				end
			end
		end

		local nameClip = card:FindFirstChild("NameClip")
		if nameClip then
			nameClip.Size = UDim2.new(1, -(80 + (isAdmin and 40 or 8)), 0, 18)
			local nl = nameClip:FindFirstChild("NameLabel")
			if nl then nl.Text = song.name or "Desconocido"; nl.TextColor3 = isActive and THEME.text or THEME.text end
		end
		local pl = card:FindFirstChild("PlaylistLabel")
		if pl then pl.Size = UDim2.new(1, -(80 + (isAdmin and 40 or 8)), 0, 14); pl.Text = song.dj and ("Lista: " .. song.dj) or "" end
		local rl = card:FindFirstChild("RequesterLabel")
		if rl then rl.Size = UDim2.new(1, -(80 + (isAdmin and 40 or 8)), 0, 14); rl.Text = song.requestedBy and ("Pedida por: " .. song.requestedBy) or "" end
	end
end

-- Pre-create queue card pool
for _ = 1, math.min(CFG.MAX_QUEUE_POOL, 15) do
	local card = createQueueCard(); card.Parent = E.queueScroll; table.insert(S.queueCardPool, card)
	if isAdmin then
		local removeBtn = card:FindFirstChild("RemoveBtn")
		if removeBtn then removeBtn.MouseButton1Click:Connect(function()
				local idx = card:GetAttribute("QueueIndex"); if idx and R.Remove then R.Remove:FireServer(idx) end
			end) end
	end
end

-- ════════════════════════════════════════════════════════════════
-- SONG CARD POOL (Library virtual scroll)
-- ════════════════════════════════════════════════════════════════
local function createSongCard()
	local card = makeCanvas(nil, 8, 102)
	card.Name = "SongCard"; card.Size = UDim2.new(1, -8, 0, CFG.CARD_HEIGHT)
	card.BackgroundColor3 = THEME.card; card.BackgroundTransparency = THEME.frameAlpha; card.Visible = false
	Modules.UI.stroked(card, 0.3)

	local coverBg = makeFrame({dim = UDim2.new(0, CFG.CARD_HEIGHT, 1, 0), bg = THEME.elevated, bgT = 0, z = 103, name = "CoverBg", parent = card})
	make("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, BorderSizePixel = 0, ZIndex = 104, Name = "DJCover", Parent = coverBg})

	local textX = CFG.CARD_HEIGHT + 8
	makeLabel({dim = UDim2.new(1, -(textX + 44), 0, 18), pos = UDim2.new(0, textX, 0, 10), font = Enum.Font.GothamBold, size = 14, truncate = Enum.TextTruncate.AtEnd, z = 103, name = "NameLabel", parent = card})
	makeLabel({dim = UDim2.new(1, -(textX + 44), 0, 14), pos = UDim2.new(0, textX, 0, 30), color = THEME.dim, font = Enum.Font.GothamBold, size = 12, truncate = Enum.TextTruncate.AtEnd, z = 103, name = "ArtistLabel", parent = card})

	local addBtn, _ = Modules.UI.outlinedCircleBtn(card, {
		size = 32, icon = ICONS.PLAY_ADD, theme = THEME, zIndex = 103,
		position = UDim2.new(1, -36, 0.5, -16), name = "AddButton",
	})
	makeImage({dim = UDim2.new(0.75, 0, 0.75, 0), pos = UDim2.new(0.125, 0, 0.125, 0), image = ICONS.LOADING, imageColor = THEME.dim, z = 105, visible = false, name = "LoadingIcon", parent = addBtn})
	local addBtnStroke = addBtn:FindFirstChildWhichIsA("UIStroke")
	addBtn.MouseEnter:Connect(function()
		if addBtnStroke then tw(addBtnStroke, 0.12, {Color = THEME.accent}) end
	end)
	addBtn.MouseLeave:Connect(function()
		if addBtnStroke then tw(addBtnStroke, 0.12, {Color = THEME.stroke}) end
	end)

	addBtn.MouseButton1Click:Connect(function()
		local songId = card:GetAttribute("SongID")
		if songId and not isInQueue(songId) and not S.pendingCardSongIds[songId] then
			S.pendingCardSongIds[songId] = true
			local iconImg = addBtn:FindFirstChild("IconImage"); local loadingIcon = addBtn:FindFirstChild("LoadingIcon")
			if iconImg then iconImg.Visible = false end
			if loadingIcon then
				loadingIcon.Visible = true; loadingIcon.Rotation = 0
				task.spawn(function()
					local t = TweenService:Create(loadingIcon, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = 360})
					t:Play(); while loadingIcon.Visible do task.wait(0.1) end; if t then t:Cancel() end
				end)
			end
			local addStroke = addBtn:FindFirstChildWhichIsA("UIStroke")
			if addStroke then addStroke.Color = THEME.accent end
			if R.Add then R.Add:FireServer(songId) end
		end
	end)
	return card
end

local function getCardFromPool()
	for _, card in ipairs(S.cardPool) do if not card.Visible then return card end end
	if #S.cardPool < CFG.MAX_POOL_SIZE then
		local c = createSongCard(); c.Parent = E.songsContainer; table.insert(S.cardPool, c); return c
	end
end

local function releaseCard(card)
	local idx = card:GetAttribute("SongIndex"); if idx then S.cardsIndex[idx] = nil end
	card.Visible = false; card:SetAttribute("SongIndex", nil); card:SetAttribute("SongID", nil)
end

local function releaseAllCards()
	S.cardsIndex = {}
	for _, card in ipairs(S.cardPool) do card.Visible = false; card:SetAttribute("SongIndex", nil); card:SetAttribute("SongID", nil) end
end

-- ════════════════════════════════════════════════════════════════
-- VIRTUAL SCROLL
-- ════════════════════════════════════════════════════════════════
local function getSongData() return virtualScrollState.isSearching and virtualScrollState.searchResults or virtualScrollState.songData end
local function getTotalSongs() return virtualScrollState.isSearching and #virtualScrollState.searchResults or virtualScrollState.totalSongs end

local function updateSongCard(card, data, index, inQ)
	if not card or not data then return end
	card:SetAttribute("SongIndex", index); card:SetAttribute("SongID", data.id); S.cardsIndex[index] = card
	local djCover = card:FindFirstChild("DJCover", true)
	if djCover and S.selectedDJInfo and S.selectedDJInfo.cover then djCover.Image = S.selectedDJInfo.cover end
	local nl = card:FindFirstChild("NameLabel", true)
	if nl then nl.Text = data.name or "Cargando..."; nl.TextColor3 = data.loaded and THEME.text or THEME.muted end
	local al = card:FindFirstChild("ArtistLabel", true)
	if al then al.Text = data.artist or ("ID: " .. data.id) end
	local ab = card:FindFirstChild("AddButton", true)
	if ab then
		local icon = ab:FindFirstChild("IconImage"); local loadingIcon = ab:FindFirstChild("LoadingIcon")
		local abStroke = ab:FindFirstChildWhichIsA("UIStroke")
		if S.pendingCardSongIds[data.id] then
			if abStroke then abStroke.Color = THEME.accent end
			if icon then icon.Visible = false end; if loadingIcon then loadingIcon.Visible = true end
		elseif inQ then
			if abStroke then abStroke.Color = THEME.success end
			if icon then icon.Image = ICONS.CHECK; icon.ImageColor3 = THEME.success; icon.Visible = true end
			if loadingIcon then loadingIcon.Visible = false end
		else
			if abStroke then abStroke.Color = THEME.stroke end
			if icon then icon.Image = ICONS.PLAY_ADD; icon.ImageColor3 = THEME.dim; icon.Visible = true end
			if loadingIcon then loadingIcon.Visible = false end
		end
	end
	card.Position = UDim2.new(0, 4, 0, (index - 1) * (CFG.CARD_HEIGHT + CFG.CARD_PADDING)); card.Visible = true
end

local function updateVisibleCards()
	if not E.songsScroll or not E.songsScroll.Parent then return end
	local totalItems = getTotalSongs()
	if totalItems == 0 then releaseAllCards(); return end
	local scrollY, vpH = E.songsScroll.CanvasPosition.Y, E.songsScroll.AbsoluteSize.Y
	local step = CFG.CARD_HEIGHT + CFG.CARD_PADDING
	local first = math.max(1, math.floor(scrollY / step) + 1 - CFG.VISIBLE_BUFFER)
	local last = math.min(totalItems, math.ceil((scrollY + vpH) / step) + CFG.VISIBLE_BUFFER)
	E.songsContainer.Size = UDim2.new(1, 0, 0, totalItems * step)
	E.songsScroll.CanvasSize = UDim2.new(0, 0, 0, totalItems * step + 20)
	for idx, card in pairs(S.cardsIndex) do
		if card and card.Visible and (idx < first or idx > last) then releaseCard(card) end
	end
	local dataSource = getSongData(); local needsFetch = {}
	for i = first, last do
		local sd = dataSource[i]
		if sd then
			local c = S.cardsIndex[i] or getCardFromPool()
			if c then updateSongCard(c, sd, i, isInQueue(sd.id)) end
		elseif not virtualScrollState.isSearching then table.insert(needsFetch, i) end
	end
	if #needsFetch > 0 and not virtualScrollState.isSearching then
		local mn, mx = math.huge, 0
		for _, idx in ipairs(needsFetch) do mn = math.min(mn, idx); mx = math.max(mx, idx) end
		local key = mn .. "-" .. mx
		if not virtualScrollState.pendingRequests[key] then
			virtualScrollState.pendingRequests[key] = true
			if R.GetSongRange and S.selectedDJ then R.GetSongRange:FireServer(S.selectedDJ, mn, mx) end
		end
	end
	virtualScrollState.firstVisibleIndex = first; virtualScrollState.lastVisibleIndex = last
end

local function connectScrollListener()
	if S.scrollConnection then S.scrollConnection:Disconnect() end
	S.scrollConnection = E.songsScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if S.scrollDebounceThread then return end
		S.scrollDebounceThread = task.delay(CFG.SCROLL_DEBOUNCE, function() S.scrollDebounceThread = nil; updateVisibleCards() end)
	end)
end

-- ════════════════════════════════════════════════════════════════
-- SEARCH
-- ════════════════════════════════════════════════════════════════
local function performSearch(query)
	if query == "" then
		virtualScrollState.isSearching = false; virtualScrollState.searchQuery = ""; virtualScrollState.searchResults = {}
		E.songCountLabel.Text = virtualScrollState.totalSongs .. " canciones"
		E.songsScroll.CanvasPosition = Vector2.new(0, 0); updateVisibleCards(); return
	end
	virtualScrollState.isSearching = true; virtualScrollState.searchQuery = query
	E.loadingIndicator.Visible = true; E.loadingIndicator.Text = "Buscando..."
	if R.SearchSongs and S.selectedDJ then R.SearchSongs:FireServer(S.selectedDJ, query) end
end

E.searchInput:GetPropertyChangedSignal("Text"):Connect(function()
	if not S.selectedDJ then return end
	if S.searchDebounce then task.cancel(S.searchDebounce) end
	S.searchDebounce = task.delay(0.3, function() performSearch(E.searchInput.Text) end)
end)

-- ════════════════════════════════════════════════════════════════
-- HEADER COVER UPDATE
-- ════════════════════════════════════════════════════════════════
local function updateHeaderCover(song)
	if not song then
		if S.currentHeaderCover ~= "" then
			S.currentHeaderCover = ""
			if E.homeBackgroundCover then
				E.homeBackgroundCover.Visible = false
				E.homeBackgroundCover.Image = ""
			end
			TweenService:Create(E.miniCover, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {ImageTransparency = 1}):Play()
			task.delay(0.3, function() E.miniCover.Image = ""; E.headerDJName.Text = "" end)
		end; return
	end
	local cover = song.djCover or ""
	if cover ~= S.currentHeaderCover then
		S.currentHeaderCover = cover
		if E.homeBackgroundCover then
			if cover ~= "" then
				E.homeBackgroundCover.Visible = true
				E.homeBackgroundCover.ImageTransparency = 1
				E.homeBackgroundCover.Image = cover
				TweenService:Create(E.homeBackgroundCover, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {ImageTransparency = 0}):Play()
			else
				E.homeBackgroundCover.Visible = false
				E.homeBackgroundCover.Image = ""
			end
		end
		TweenService:Create(E.miniCover, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {ImageTransparency = 1}):Play()
		task.delay(0.25, function()
			E.miniCover.Image = cover
			TweenService:Create(E.miniCover, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {ImageTransparency = 0}):Play()
		end)
	end
	E.headerDJName.Text = "Pedida por: " .. (song.requestedBy or song.dj or "Desconocido")
end

-- ════════════════════════════════════════════════════════════════
-- DJ LIST
-- ════════════════════════════════════════════════════════════════
local function clearChildren(parent, keep)
	for _, child in pairs(parent:GetChildren()) do
		local skip = false
		for _, cls in ipairs(keep or {}) do if child:IsA(cls) then skip = true; break end end
		if not skip then child:Destroy() end
	end
end

local function selectDJ(djName, djData, card)
	if S.selectedDJ == djName then return end
	if S.selectedDJCard and S.selectedDJCard ~= card then
		S.selectedDJCard.BackgroundColor3 = THEME.elevated
		S.selectedDJCard.BackgroundTransparency = THEME.frameAlpha or 0.3
		local pn = S.selectedDJCard:FindFirstChild("DJNameLabel"); if pn then tw(pn, 0.25, {TextColor3 = THEME.text}) end
		local pc = S.selectedDJCard:FindFirstChild("CountLabel"); if pc then tw(pc, 0.25, {TextColor3 = THEME.muted}) end
	end
	S.selectedDJ = djName; S.selectedDJInfo = djData; S.selectedDJCard = card
	card.BackgroundColor3 = THEME.accent; card.BackgroundTransparency = 0
	local dn = card:FindFirstChild("DJNameLabel"); if dn then tw(dn, 0.25, {TextColor3 = THEME.text}) end
	local dc = card:FindFirstChild("CountLabel"); if dc then tw(dc, 0.25, {TextColor3 = THEME.text}) end

	virtualScrollState.totalSongs = djData.songCount; virtualScrollState.songData = {}
	virtualScrollState.searchResults = {}; virtualScrollState.isSearching = false
	virtualScrollState.searchQuery = ""; virtualScrollState.pendingRequests = {}

	E.searchInput.Text = ""; E.songCountLabel.Text = djData.songCount .. " canciones"; E.songCountLabel.Visible = true
	E.songsPlaceholder.Visible = false; E.songsTitle.Text = "CANCIONES"
	releaseAllCards(); E.songsScroll.CanvasPosition = Vector2.new(0, 0)
	E.loadingIndicator.Visible = true; E.loadingIndicator.Text = "Cargando canciones..."; E.loadingIndicator.Position = UDim2.new(0, 0, 0, 4)

	local totalH = djData.songCount * (CFG.CARD_HEIGHT + CFG.CARD_PADDING)
	E.songsContainer.Size = UDim2.new(1, 0, 0, totalH); E.songsScroll.CanvasSize = UDim2.new(0, 0, 0, totalH + 20)
	connectScrollListener()
	if R.GetSongRange then R.GetSongRange:FireServer(djName, 1, math.min(djData.songCount, 25)) end
end

local function drawDJs()
	clearChildren(E.djsScroll, {"UIListLayout", "UIPadding"}); S.selectedDJCard = nil
	if #S.allDJs == 0 then makeLabel({text = "Sin listas", color = THEME.muted, size = 13, dim = UDim2.new(1, 0, 0, 60), parent = E.djsScroll}); return end
	for _, dj in ipairs(S.allDJs) do
		local isSel = S.selectedDJ == dj.name
		local card = makeBtn({dim = UDim2.new(1, 0, 0, 52), bg = isSel and THEME.accent or THEME.elevated, z = 102, round = 8, name = "DJCard", parent = E.djsScroll})
		card.BackgroundTransparency = isSel and 0 or (THEME.frameAlpha or 0.3); card.AutoButtonColor = false
		if isSel then S.selectedDJCard = card end
		make("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = card})
		makeLabel({dim = UDim2.new(1, 0, 0, 20), pos = UDim2.new(0, 0, 0, 8), text = dj.name, font = Enum.Font.GothamBold, size = 14, color = isSel and THEME.text or THEME.text, truncate = Enum.TextTruncate.AtEnd, z = 103, name = "DJNameLabel", parent = card})
		makeLabel({dim = UDim2.new(1, 0, 0, 16), pos = UDim2.new(0, 0, 0, 28), text = dj.songCount .. " canciones", font = Enum.Font.Gotham, size = 12, color = isSel and THEME.text or THEME.muted, z = 103, name = "CountLabel", parent = card})
		card.MouseEnter:Connect(function() if S.selectedDJCard ~= card then tw(card, 0.15, {BackgroundTransparency = 0.15}) end end)
		card.MouseLeave:Connect(function() if S.selectedDJCard ~= card then tw(card, 0.15, {BackgroundTransparency = THEME.frameAlpha or 0.3}) end end)
		card.MouseButton1Click:Connect(function() selectDJ(dj.name, dj, card) end)
	end
end

-- ════════════════════════════════════════════════════════════════
-- PROGRESS BAR UPDATE
-- ════════════════════════════════════════════════════════════════
local function updateProgressBar(dt)
	if not S.currentSoundObject then S.currentSoundObject = workspace:FindFirstChild("QueueSound") end
	if not S.currentSoundObject or not S.currentSoundObject:IsA("Sound") or not S.currentSoundObject.Parent then
		if S.progressTween then S.progressTween:Cancel(); S.progressTween = nil end
		E.progressFill.Size = UDim2.new(0, 0, 1, 0); E.currentTimeLabel.Text = "0:00"; E.totalTimeLabel.Text = "0:00"
		S.progressAccum = 0; if not S.currentSong then E.songTitle.Text = "No song playing" end; return
	end
	local total = S.currentSoundObject.TimeLength
	if total <= 0 then E.progressFill.Size = UDim2.new(0, 0, 1, 0); E.currentTimeLabel.Text = "0:00"; E.totalTimeLabel.Text = "0:00"; return end
	S.progressAccum = S.progressAccum + dt
	if S.progressAccum < CFG.PROGRESS_RATE then return end
	S.progressAccum = 0
	local rawPos = S.currentSoundObject.TimePosition
	local frac = math.clamp(rawPos / total, 0, 1)
	if S.progressTween then S.progressTween:Cancel() end
	S.progressTween = TweenService:Create(E.progressFill, TweenInfo.new(CFG.PROGRESS_RATE + 0.02, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(frac, 0, 1, 0)})
	S.progressTween:Play(); E.currentTimeLabel.Text = formatTime(rawPos); E.totalTimeLabel.Text = formatTime(total)
end

-- ════════════════════════════════════════════════════════════════
-- VISUALIZER
-- ════════════════════════════════════════════════════════════════
local function startVisualizer()
	if S.visualizerConnection then S.visualizerConnection:Disconnect() end
	local vizAccum = 0
	S.visualizerConnection = RunService.Heartbeat:Connect(function(dt)
		vizAccum = vizAccum + dt; if vizAccum < 0.033 then return end
		local elapsed = vizAccum; vizAccum = 0
		local loudness, hasAudio = 0, false
		if S.currentSoundObject and S.currentSoundObject:IsA("Sound") and S.currentSoundObject.IsPlaying then
			loudness = math.clamp(S.currentSoundObject.PlaybackLoudness / 300, 0, 1); hasAudio = loudness > 0.001
		end
		local time = tick()
		for i, barData in ipairs(S.visualizerBars) do
			local bar = barData.frame
			if bar and bar.Parent then
				local targetH, maxH = 0, VISUALIZER.BAR_MAX_H
				if hasAudio then
					targetH = math.clamp(loudness * maxH * (0.4 + 0.6 * (1 - barData.freqWeight)) * (math.sin(time * 8 + barData.phase * 3) * 0.3 + 0.7) * (1 - barData.freqWeight * 0.5), 2, maxH)
				else
					targetH = 2 + (math.floor(maxH * 0.35) - 2) * (math.sin(time * 1.8 + barData.phase) * 0.5 + 0.5) * (math.sin(time * 1.26 + barData.phase * 1.3) * 0.3 + 0.7)
				end
				barData.currentH = barData.currentH + (targetH - barData.currentH) * ((targetH > barData.currentH) and 12 or 8) * elapsed
				local h = math.floor(math.clamp(barData.currentH, 2, maxH))
				bar.Size = UDim2.new(0, VISUALIZER.BAR_WIDTH, 0, h)
				bar.Position = UDim2.new(bar.Position.X.Scale, bar.Position.X.Offset, 1, -h)
				local t = math.clamp((h - 2) / (maxH - 2), 0, 1)
				bar.BackgroundColor3 = VISUALIZER.COLOR_LOW:Lerp(VISUALIZER.COLOR_HIGH, t)
				bar.BackgroundTransparency = hasAudio and (0.05 + (1 - t) * 0.15) or 0.35
			end
		end
	end)
end

-- ════════════════════════════════════════════════════════════════
-- UI OPEN/CLOSE
-- ════════════════════════════════════════════════════════════════
local function openUI()
	if modal:isModalOpen() then return end
	drawQueue(); if #S.allDJs > 0 then drawDJs() end
	modal:open()
	if S.progressConnection then S.progressConnection:Disconnect() end
	S.progressConnection = RunService.Heartbeat:Connect(updateProgressBar)
	startVisualizer()
end

local function closeUI()
	if modal:isModalOpen() then modal:close() end
	if S.visualizerConnection then S.visualizerConnection:Disconnect(); S.visualizerConnection = nil end
end

-- ════════════════════════════════════════════════════════════════
-- EVENTS
-- ════════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape and modal:isModalOpen() then
		Modules.GlobalModalManager:closeModal("Music")
	elseif input.KeyCode == Enum.KeyCode.Return and E.volInput.Visible then
		applyVolumeInput()
	end
end)

-- ════════════════════════════════════════════════════════════════
-- REMOTE UPDATES
-- ════════════════════════════════════════════════════════════════
local function updateNowPlayingInfo(song)
	if song then E.songTitle.Text = song.name; E.headerDJName.Text = "Pedida por: " .. (song.requestedBy or song.artist or "Desconocido")
	else E.songTitle.Text = "Sin cancion"; E.headerDJName.Text = "" end
end

local function processUpdate(data)
	S.playQueue = data.queue or {}; S.currentSong = data.currentSong
	S.currentSoundObject = workspace:FindFirstChild("QueueSound")
	updateNowPlayingInfo(S.currentSong); updateHeaderCover(S.currentSong); drawQueue()
	if S.selectedDJ then updateVisibleCards() end
	local newDJs = data.djs or S.allDJs; local djsChanged = #newDJs ~= #S.allDJs
	if not djsChanged then
		for i, dj in ipairs(newDJs) do
			if not S.allDJs[i] or S.allDJs[i].name ~= dj.name or S.allDJs[i].songCount ~= dj.songCount then djsChanged = true; break end
		end
	end
	if djsChanged then S.allDJs = newDJs; drawDJs() end
end

if R.Update then
	R.Update.OnClientEvent:Connect(function(data)
		local now = tick()
		if (now - S.lastUpdateTime) < CFG.UPDATE_THROTTLE then
			S.pendingUpdate = data
			if not S.pendingUpdate._scheduled then
				S.pendingUpdate._scheduled = true
				task.delay(CFG.UPDATE_THROTTLE, function() if S.pendingUpdate then S.lastUpdateTime = tick(); processUpdate(S.pendingUpdate); S.pendingUpdate = nil end end)
			end; return
		end
		S.lastUpdateTime = now; S.pendingUpdate = nil; processUpdate(data)
	end)
end

if R.GetDJs then R.GetDJs.OnClientEvent:Connect(function(d) S.allDJs = (d and (d.djs or d)) or S.allDJs; drawDJs() end) end

if R.GetSongRange then
	R.GetSongRange.OnClientEvent:Connect(function(data)
		if not data or data.djName ~= S.selectedDJ then return end
		E.loadingIndicator.Visible = false
		for _, song in ipairs(data.songs or {}) do virtualScrollState.songData[song.index] = song end
		virtualScrollState.pendingRequests[data.startIndex .. "-" .. data.endIndex] = nil; updateVisibleCards()
	end)
end

if R.SearchSongs then
	R.SearchSongs.OnClientEvent:Connect(function(data)
		if not data or data.djName ~= S.selectedDJ then return end
		E.loadingIndicator.Visible = false; virtualScrollState.searchResults = data.songs or {}
		local total = data.totalInDJ or virtualScrollState.totalSongs
		local countText = #virtualScrollState.searchResults .. " / " .. total .. " canciones"
		if data.cachedCount and data.cachedCount < total then countText = countText .. " " .. math.floor(data.cachedCount / total * 100) .. "%" end
		E.songCountLabel.Text = countText; E.songsScroll.CanvasPosition = Vector2.new(0, 0); updateVisibleCards()
	end)
end

if R.GetSongsByDJ then
	R.GetSongsByDJ.OnClientEvent:Connect(function(data)
		if not data or data.djName ~= S.selectedDJ then return end
		virtualScrollState.totalSongs = data.total or 0; E.songCountLabel.Text = data.total .. " canciones"
		local totalH = data.total * (CFG.CARD_HEIGHT + CFG.CARD_PADDING)
		E.songsContainer.Size = UDim2.new(1, 0, 0, totalH); E.songsScroll.CanvasSize = UDim2.new(0, 0, 0, totalH + 20)
	end)
end

-- ════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ════════════════════════════════════════════════════════════════
if R.GetDJs then R.GetDJs:FireServer() end

for _ = 1, CFG.MAX_POOL_SIZE do
	local card = createSongCard(); card.Parent = E.songsContainer; table.insert(S.cardPool, card)
end

switchTab("Home")

_G.OpenMusicUI = openUI
_G.CloseMusicUI = closeUI