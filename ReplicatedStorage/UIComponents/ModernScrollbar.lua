--[[
	MODERN SCROLLBAR - Componente reutilizable de scrollbar personalizado
	Autor: ignxts

	Uso básico:
		ModernScrollbar.setup(scrollFrame, parentFrame, THEME)

	Con opciones:
		ModernScrollbar.setup(scrollFrame, parentFrame, THEME, {
			position    = "right" | "left",   -- lado donde aparece (default: "right")
			offset      = 0,                  -- px de separación extra desde el borde (default: 0)
			width       = 4,                  -- ancho base en px (default: 4)
			widthHover  = 6,                  -- ancho al hacer hover (default: width + 2)
			paddingV    = 12,                 -- padding vertical en px (default: 12)
			color       = Color3,             -- color del thumb (default: THEME.accent)
			colorHover  = Color3,             -- color del thumb en hover (default: THEME.accent)
			transparency     = 0.3,           -- transparencia base del thumb
			transparencyHover = 0,            -- transparencia en hover
			zIndex      = 115,                -- ZIndex base (default: 115)
		})

	Retorna:
		{ container, track, thumb, update }
]]

local TweenService = game:GetService("TweenService")

local ModernScrollbar = {}

function ModernScrollbar.setup(scrollFrame, parentFrame, THEME, options)
	if not scrollFrame or not parentFrame or not THEME then
		warn("[ModernScrollbar] scrollFrame, parentFrame y THEME son requeridos")
		return
	end

	options = options or {}

	local position          = options.position          or "right"
	local offset            = options.offset            or 0
	local width             = options.width             or 4
	local widthHover        = options.widthHover        or (width + 2)
	local paddingV          = options.paddingV          or 6
	local color             = options.color             or THEME.accent
	local colorHover        = options.colorHover        or THEME.accent
	local transparency      = options.transparency      or 0.3
	local transparencyHover = options.transparencyHover or 0
	local zIndex            = options.zIndex            or 115

	-- ── Mirror frame (mismo Size/Position que scrollFrame) ────────
	-- Así el container usa coords relativas al scrollFrame sin math complejo
	local mirror = Instance.new("Frame")
	mirror.Name = "ScrollbarMirror"
	mirror.Size = scrollFrame.Size
	mirror.Position = scrollFrame.Position
	mirror.BackgroundTransparency = 1
	mirror.BorderSizePixel = 0
	mirror.ZIndex = zIndex
	mirror.ClipsDescendants = false
	mirror.Parent = parentFrame

	-- Mantener el espejo sincronizado si el scrollFrame cambia
	scrollFrame:GetPropertyChangedSignal("Size"):Connect(function()
		mirror.Size = scrollFrame.Size
	end)
	scrollFrame:GetPropertyChangedSignal("Position"):Connect(function()
		mirror.Position = scrollFrame.Position
	end)

	-- ── Container (relativo al mirror = relativo al scrollFrame) ──
	local container = Instance.new("Frame")
	container.Name = "ScrollbarContainer"
	container.Size = UDim2.new(0, width, 1, -paddingV * 2)
	container.AnchorPoint = Vector2.new(0, 0)

	if position == "left" then
		container.Position = UDim2.new(0, -width - offset, 0, paddingV)
	else
		container.Position = UDim2.new(1, offset, 0, paddingV)
	end

	container.BackgroundTransparency = 1
	container.ZIndex = zIndex
	container.Visible = false
	container.Parent = mirror

	-- ── Track ──────────────────────────────────────────────────────
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 1, 0)
	track.BackgroundColor3 = THEME.stroke
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.ZIndex = zIndex
	track.Parent = container
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track

	-- ── Thumb ──────────────────────────────────────────────────────
	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.Size = UDim2.new(1, 0, 0.3, 0)
	thumb.Position = UDim2.new(0, 0, 0, 0)
	thumb.BackgroundColor3 = color
	thumb.BackgroundTransparency = 1
	thumb.BorderSizePixel = 0
	thumb.ZIndex = zIndex + 1
	thumb.Parent = container
	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(0, 4)
	thumbCorner.Parent = thumb

	-- ── Update + Auto-hide logic ───────────────────────────────────
	local needsScroll  = false
	local hoverScroll  = false   -- mouse sobre el scrollFrame
	local hoverBar     = false   -- mouse sobre track/thumb
	local hideThread   = nil     -- debounce para evitar flicker

	local function refreshFade()
		local show = needsScroll and (hoverScroll or hoverBar)
		if show then
			TweenService:Create(track, TweenInfo.new(0.15), { BackgroundTransparency = 0.7 }):Play()
			TweenService:Create(thumb, TweenInfo.new(0.15), {
				BackgroundTransparency = hoverBar and transparencyHover or transparency
			}):Play()
		else
			TweenService:Create(track, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(thumb, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end
	end

	local function update()
		local canvasH = scrollFrame.AbsoluteCanvasSize.Y
		local windowH = scrollFrame.AbsoluteWindowSize.Y

		if windowH < 1 then return end

		if canvasH <= windowH + 1 then
			needsScroll = false
			container.Visible = false
			return
		end
		needsScroll = true
		container.Visible = true

		local thumbRatio = math.clamp(windowH / canvasH, 0.08, 1)
		local maxScroll  = canvasH - windowH
		local scrollPct  = maxScroll > 0 and math.clamp(scrollFrame.CanvasPosition.Y / maxScroll, 0, 1) or 0

		thumb.Size     = UDim2.new(1, 0, thumbRatio, 0)
		thumb.Position = UDim2.new(0, 0, scrollPct * (1 - thumbRatio), 0)
	end

	scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(update)
	scrollFrame:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(update)
	scrollFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(update)
	scrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(update)
	end)

	-- Sincronizar visibilidad: si scrollFrame se oculta, ocultar mirror completo
	scrollFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not scrollFrame.Visible then
			mirror.Visible = false
		else
			mirror.Visible = true
			task.defer(update)
		end
	end)

	-- ── Hover: scrollFrame → mostrar/ocultar scrollbar con fade ───
	scrollFrame.MouseEnter:Connect(function()
		hoverScroll = true
		if hideThread then task.cancel(hideThread); hideThread = nil end
		refreshFade()
	end)
	scrollFrame.MouseLeave:Connect(function()
		hoverScroll = false
		-- Pequeño delay para evitar flicker al mover mouse hacia la barra
		hideThread = task.delay(0.12, function()
			hideThread = nil
			refreshFade()
		end)
	end)

	-- ── Hover: barra → mantener visible + expandir ────────────────
	local function onBarEnter()
		hoverBar = true
		if hideThread then task.cancel(hideThread); hideThread = nil end
		refreshFade()
		TweenService:Create(container, TweenInfo.new(0.15), {
			Size = UDim2.new(0, widthHover, 1, -paddingV * 2)
		}):Play()
	end

	local function onBarLeave()
		hoverBar = false
		refreshFade()
		TweenService:Create(container, TweenInfo.new(0.2), {
			Size = UDim2.new(0, width, 1, -paddingV * 2)
		}):Play()
	end

	track.MouseEnter:Connect(onBarEnter)
	thumb.MouseEnter:Connect(onBarEnter)
	track.MouseLeave:Connect(onBarLeave)
	thumb.MouseLeave:Connect(onBarLeave)

	update()

	return {
		container = container,
		track     = track,
		thumb     = thumb,
		update    = update,
	}
end

return ModernScrollbar
