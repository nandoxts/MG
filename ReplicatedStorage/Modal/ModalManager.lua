--[[
	ModalManager - Sistema centralizado de modales (Versión Responsive Mejorada)
]]

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local THEME = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThemeConfig"))

local function getScreenSize(screenGui)
	-- Intentar múltiples métodos para obtener el tamaño real
	local size = screenGui.AbsoluteSize

	if size.X > 0 and size.Y > 0 then
		return size
	end

	-- Método 2: Viewport de la cámara
	local camera = workspace.CurrentCamera
	if camera then
		size = camera.ViewportSize
		if size.X > 0 and size.Y > 0 then
			return size
		end
	end

	-- Método 3: Parent del ScreenGui
	local parent = screenGui.Parent
	if parent and parent:IsA("PlayerGui") then
		local player = parent.Parent
		if player and player:IsA("Player") then
			local mouse = player:GetMouse()
			if mouse then
				size = Vector2.new(mouse.ViewSizeX, mouse.ViewSizeY)
				if size.X > 0 and size.Y > 0 then
					return size
				end
			end
		end
	end

	-- Fallback seguro basado en el tipo de dispositivo
	local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	return isMobile and Vector2.new(800, 600) or Vector2.new(1920, 1080)
end

local function isMobileDevice()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function calculateModalSize(screenSize, baseWidth, baseHeight, isMobile)
	if isMobile then
		-- Modo móvil: usar porcentajes con márgenes seguros
		local marginX = math.max(screenSize.X * 0.05, 16) -- Mínimo 5% o 16px
		local marginY = math.max(screenSize.Y * 0.08, 40) -- Mínimo 8% o 40px

		local width = screenSize.X - (marginX * 2)
		local height = screenSize.Y - (marginY * 2)

		-- Limites razonables para móvil
		width = math.clamp(width, 280, 700)
		height = math.clamp(height, 300, screenSize.Y * 0.9)

		return width, height
	else
		-- Modo escritorio: respetar base con límites porcentuales
		local maxWidth = screenSize.X * 0.85
		local maxHeight = screenSize.Y * 0.85

		local width = math.min(baseWidth or 980, maxWidth)
		local height = math.min(baseHeight or 620, maxHeight)

		-- Asegurar mínimos
		width = math.max(width, 400)
		height = math.max(height, 300)

		return width, height
	end
end

local function rounded(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
	return c
end

local function stroked(inst, alpha, color)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.stroke
	s.Thickness = 1
	s.Transparency = alpha or THEME.mediumAlpha or 0.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local ModalManager = {}
ModalManager.__index = ModalManager

function ModalManager.new(config)
	local self = setmetatable({}, ModalManager)

	self.screenGui = config.screenGui
	self.panelName = config.panelName or "ModalPanel"
	self.baseWidth = config.panelWidth
	self.baseHeight = config.panelHeight
	self.cornerRadius = config.cornerRadius or 12
	self.enableBlur = config.enableBlur ~= false
	self.blurSize = config.blurSize or 14
	self.onOpen = config.onOpen
	self.onClose = config.onClose

	self.isOpen = false
	self.activeTweens = {}
	self.connections = {}
	-- Background image for the panel (optional)
	self.panelBackgroundImage = config.panelBackgroundImage or nil
	self.panelBackgroundTransparency = config.panelBackgroundTransparency or 0.85

	-- Detectar dispositivo y calcular tamaño inicial
	self:_updateDimensions()

	-- Crear elementos visuales
	self:_createOverlay()
	self:_createBlur()
	self:_createPanel()

	-- Escuchar cambios de tamaño de pantalla
	self:_setupResponsiveListeners()

	return self
end

function ModalManager:_updateDimensions()
	local screenSize = getScreenSize(self.screenGui)
	local mobile = isMobileDevice()

	self.panelWidth, self.panelHeight = calculateModalSize(
		screenSize,
		self.baseWidth,
		self.baseHeight,
		mobile
	)

	self.isMobile = mobile
end

function ModalManager:_setupResponsiveListeners()
	-- Actualizar cuando cambie el tamaño de la ventana/pantalla
	local connection = self.screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if not self.isOpen then return end

		self:_updateDimensions()

		-- Actualizar tamaño del panel suavemente
		local newSize = UDim2.new(0, self.panelWidth, 0, self.panelHeight)
		local sizeTween = TweenService:Create(
			self.panel,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad),
			{Size = newSize}
		)
		sizeTween:Play()
	end)

	table.insert(self.connections, connection)

	-- Actualizar cuando cambie la orientación (móvil)
	local cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if not self.isOpen then return end

		task.wait(0.1) -- Pequeño delay para evitar múltiples llamadas
		self:_updateDimensions()

		local newSize = UDim2.new(0, self.panelWidth, 0, self.panelHeight)
		self.panel.Size = newSize
	end)

	table.insert(self.connections, cameraConnection)
end

function ModalManager:_createOverlay()
	self.overlay = Instance.new("Frame")
	self.overlay.Name = "Overlay"
	self.overlay.BackgroundColor3 = THEME.bg
	self.overlay.BorderSizePixel = 0
	self.overlay.Size = UDim2.fromScale(1, 1)
	self.overlay.Position = UDim2.fromScale(0, 0)
	self.overlay.BackgroundTransparency = 1
	self.overlay.Visible = false
	self.overlay.ZIndex = 95
	self.overlay.Parent = self.screenGui
end

function ModalManager:_createBlur()
	if not self.enableBlur then return end

	self.blur = Instance.new("BlurEffect")
	self.blur.Size = 0
	self.blur.Enabled = false
	self.blur.Parent = Lighting
end

function ModalManager:_createPanel()
	self.panel = Instance.new("Frame")
	self.panel.Name = self.panelName
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.Position = UDim2.new(0.5, 0, 1.5, 0)
	self.panel.BackgroundColor3 = THEME.panel or Color3.fromRGB(18, 18, 22)
	self.panel.BackgroundTransparency = THEME.lightAlpha or 0.2
	self.panel.BorderSizePixel = 0
	self.panel.Visible = false
	self.panel.ZIndex = 100
	self.panel.Size = UDim2.new(0, self.panelWidth, 0, self.panelHeight)
	self.panel.Parent = self.screenGui

	rounded(self.panel, self.cornerRadius)
	stroked(self.panel, THEME.mediumAlpha or 0.5)

	-- CanvasGroup: recorta hijos respetando UICorner en todos los modales
	self.canvas = Instance.new("CanvasGroup")
	self.canvas.Name = "Canvas"
	self.canvas.Size = UDim2.new(1, 0, 1, 0)
	self.canvas.BackgroundTransparency = 1
	self.canvas.BorderSizePixel = 0
	self.canvas.GroupTransparency = 0
	self.canvas.ZIndex = self.panel.ZIndex
	self.canvas.Parent = self.panel
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, self.cornerRadius)
		c.Parent = self.canvas
	end

	-- Optional background image for the panel (behind content)
	if self.panelBackgroundImage and self.panelBackgroundImage ~= "" then
		local bg = Instance.new("ImageLabel")
		bg.Name = "PanelBackgroundImage"
		bg.Size = UDim2.fromScale(1, 1)
		bg.Position = UDim2.fromScale(0, 0)
		bg.BackgroundTransparency = 1
		bg.Image = self.panelBackgroundImage
		bg.ImageTransparency = self.panelBackgroundTransparency or 0.85
		bg.ScaleType = Enum.ScaleType.Crop
		bg.ZIndex = self.panel.ZIndex
		bg.Parent = self.panel

		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, self.cornerRadius)
		bgCorner.Parent = bg
	end
end

function ModalManager:open()
	if self.isOpen then return end
	self.isOpen = true

	-- Recalcular dimensiones antes de abrir (por si acaso)
	self:_updateDimensions()
	self.panel.Size = UDim2.new(0, self.panelWidth, 0, self.panelHeight)

	self.panel.Visible = true
	self.overlay.Visible = true

	local overlayTween = TweenService:Create(
		self.overlay,
		TweenInfo.new(0.22),
		{BackgroundTransparency = THEME.mediumAlpha or 0.5}
	)
	table.insert(self.activeTweens, overlayTween)
	overlayTween:Play()

	if self.blur then
		self.blur.Enabled = true
		local blurTween = TweenService:Create(
			self.blur,
			TweenInfo.new(0.22),
			{Size = self.blurSize}
		)
		table.insert(self.activeTweens, blurTween)
		blurTween:Play()
	end

	self.panel.Position = UDim2.fromScale(0.5, 1.1)
	local panelTween = TweenService:Create(
		self.panel,
		TweenInfo.new(0.28, Enum.EasingStyle.Quad),
		{Position = UDim2.fromScale(0.5, 0.5)}
	)
	table.insert(self.activeTweens, panelTween)
	panelTween:Play()

	if self.onOpen then
		self.onOpen()
	end
end

function ModalManager:close()
	if not self.isOpen then return end
	self.isOpen = false

	for _, tween in ipairs(self.activeTweens) do
		if tween then
			pcall(function() tween:Cancel() end)
		end
	end
	self.activeTweens = {}

	local panelTween = TweenService:Create(
		self.panel,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad),
		{Position = UDim2.fromScale(0.5, 1.1)}
	)
	table.insert(self.activeTweens, panelTween)
	panelTween:Play()

	local overlayTween = TweenService:Create(
		self.overlay,
		TweenInfo.new(0.22),
		{BackgroundTransparency = 1}
	)
	table.insert(self.activeTweens, overlayTween)
	overlayTween:Play()

	task.delay(0.22, function()
		self.overlay.Visible = false
		self.panel.Visible = false
	end)

	if self.blur then
		local blurTween = TweenService:Create(
			self.blur,
			TweenInfo.new(0.22),
			{Size = 0}
		)
		table.insert(self.activeTweens, blurTween)
		blurTween:Play()
		task.delay(0.22, function()
			if self.blur then 
				self.blur.Enabled = false 
			end
		end)
	end

	if self.onClose then
		self.onClose()
	end
end

function ModalManager:getPanel()
	return self.panel
end

function ModalManager:getCanvas()
	return self.canvas
end

function ModalManager:isModalOpen()
	return self.isOpen
end

function ModalManager:destroy()
	-- Limpiar connections
	for _, connection in ipairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.connections = {}

	-- Cancelar tweens activos
	for _, tween in ipairs(self.activeTweens) do
		if tween then
			pcall(function() tween:Cancel() end)
		end
	end

	-- Destruir elementos
	if self.overlay then self.overlay:Destroy() end
	if self.panel then self.panel:Destroy() end
	if self.blur then self.blur:Destroy() end
end

return ModalManager