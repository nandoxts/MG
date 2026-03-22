--[[
	SubTabs - Componente reutilizable de sub-tabs con indicador deslizante
	Estilo: MusicSystem (sliding indicator + transparent buttons)
	Uso:
		local SubTabs = require(...)
		local subTabs = SubTabs.new(parent, THEME, {
			tabs = { {id = "actual", label = "ACTUAL"}, {id = "dj", label = "DJ"} },
			height = 38,
			default = "actual",
			z = 215,
			textSize = 13,
		})

		-- Registrar panel de cada tab (opcional)
		subTabs:register("actual", panel)
		subTabs:register("dj", panel)

		-- Cambiar tab
		subTabs:select("dj")

		-- Callback
		subTabs.onSwitch = function(tabId) ... end
]]

local TweenService = game:GetService("TweenService")

local SubTabs = {}
SubTabs.__index = SubTabs

local TW_SLIDE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TW_COLOR = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function SubTabs.new(parent, THEME, config)
	local self = setmetatable({}, SubTabs)

	config = config or {}
	local tabs = config.tabs or {}
	local height = config.height or 38
	local defaultTab = config.default or (tabs[1] and tabs[1].id)
	local z = config.z or 215
	local textSize = config.textSize or 13

	self.THEME = THEME
	self.activeId = nil
	self.buttons = {}
	self.panels = {}
	self.tabOrder = {}
	self.onSwitch = nil

	local tabCount = #tabs
	local btnWidth = tabCount > 0 and (1 / tabCount) or 1

	for idx, tabDef in ipairs(tabs) do
		self.tabOrder[tabDef.id] = idx
	end

	-- Barra exterior (fondo)
	local bar = Instance.new("Frame")
	bar.Name = "SubTabBar"
	bar.Size = UDim2.new(1, 0, 0, height)
	bar.BackgroundColor3 = THEME.bg
	bar.BorderSizePixel = 0
	bar.ZIndex = z
	bar.Parent = parent

	-- Contenedor interior redondeado (como MusicSystem tabContainer)
	local pad = 4
	local container = Instance.new("Frame")
	container.Name = "TabContainer"
	container.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
	container.Position = UDim2.new(0, pad, 0, pad)
	container.BackgroundColor3 = THEME.card or Color3.fromRGB(35, 35, 35)
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.ZIndex = z
	container.Parent = bar

	local innerH = height - pad * 2
	local cornerRadius = math.floor(innerH / 2)

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, cornerRadius)
	containerCorner.Parent = container

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = THEME.stroke or Color3.fromRGB(60, 60, 60)
	containerStroke.Thickness = 1
	containerStroke.Transparency = 0.25
	containerStroke.Parent = container

	-- Indicador deslizante (accent, detrás de los botones)
	local indicatorPad = 3
	local indicator = Instance.new("Frame")
	indicator.Name = "TabIndicator"
	indicator.Size = UDim2.new(btnWidth, -indicatorPad * 2, 1, -indicatorPad * 2)
	indicator.Position = UDim2.new(0, indicatorPad, 0, indicatorPad)
	indicator.BackgroundColor3 = THEME.accent
	indicator.BorderSizePixel = 0
	indicator.ZIndex = z + 1
	indicator.Parent = container

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0, math.max(cornerRadius - indicatorPad, 4))
	indicatorCorner.Parent = indicator

	self.indicator = indicator
	self.btnWidthScale = btnWidth
	self.indicatorPad = indicatorPad

	-- Botones (transparentes, encima del indicador)
	for idx, tabDef in ipairs(tabs) do
		local btn = Instance.new("TextButton")
		btn.Name = tabDef.id
		btn.Size = UDim2.new(btnWidth, 0, 1, 0)
		btn.Position = UDim2.new(btnWidth * (idx - 1), 0, 0, 0)
		btn.BackgroundTransparency = 1
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = textSize
		btn.TextColor3 = THEME.muted
		btn.Text = tabDef.label
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.ZIndex = z + 2
		btn.Parent = container

		self.buttons[tabDef.id] = btn

		btn.MouseButton1Click:Connect(function()
			self:select(tabDef.id)
		end)
	end

	self.bar = bar
	self.height = height

	-- Seleccionar default sin animación
	if defaultTab then
		self:_setActive(defaultTab, true)
	end

	return self
end

function SubTabs:register(tabId, panel)
	self.panels[tabId] = panel
	panel.Visible = (tabId == self.activeId)
end

function SubTabs:_setActive(tabId, instant)
	local THEME = self.THEME
	self.activeId = tabId

	local idx = self.tabOrder[tabId] or 1
	local pad = self.indicatorPad
	local targetPos = UDim2.new(self.btnWidthScale * (idx - 1), pad, 0, pad)

	-- Deslizar indicador
	if instant then
		self.indicator.Position = targetPos
	else
		TweenService:Create(self.indicator, TW_SLIDE, {Position = targetPos}):Play()
	end

	-- Actualizar colores de texto
	for id, btn in pairs(self.buttons) do
		local targetColor = (id == tabId) and THEME.text or THEME.muted
		if instant then
			btn.TextColor3 = targetColor
		else
			TweenService:Create(btn, TW_COLOR, {TextColor3 = targetColor}):Play()
		end
	end
end

function SubTabs:select(tabId)
	if tabId == self.activeId then return end

	local oldId = self.activeId
	local oldPanel = self.panels[oldId]
	local newPanel = self.panels[tabId]

	self:_setActive(tabId)

	-- Cambiar paneles (sin animación de slide — show/hide directo)
	if oldPanel then oldPanel.Visible = false end
	if newPanel then newPanel.Visible = true end

	if self.onSwitch then
		task.defer(self.onSwitch, tabId)
	end
end

function SubTabs:getActiveId()
	return self.activeId
end

return SubTabs
