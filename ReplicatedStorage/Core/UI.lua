-- ════════════════════════════════════════════════════════════════
-- UI HELPERS CENTRALIZADOS
-- ════════════════════════════════════════════════════════════════
local UI = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local THEME = require(game.ReplicatedStorage.Config.ThemeConfig)

local trackFunc = nil
local loadingConnection = nil

-- ════════════════════════════════════════════════════════════════
-- ICONOS GLOBALES
-- ════════════════════════════════════════════════════════════════
UI.ICONS = {
	PLAY_ADD = "rbxassetid://106062824601262",
	CHECK    = "rbxassetid://102926522001210",
	DELETE   = "rbxassetid://100580390387788",
	LOADING  = "rbxassetid://72909990569897",
	SKIP     = "rbxassetid://130796780610204",
	BACK     = "rbxassetid://97043688093134",
	GIFT     = "rbxassetid://96461536106849",
	ADDED    = "rbxassetid://87382742337623",
}

-- ════════════════════════════════════════════════════════════════
-- GENÉRICOS (make, tween)
-- ════════════════════════════════════════════════════════════════
function UI.make(class, props)
	local i = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then i[k] = v end
	end
	if props.Parent then i.Parent = props.Parent end
	return i
end

function UI.tween(obj, t, props)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

-- ════════════════════════════════════════════════════════════════
-- UTILIDADES BASE
-- ════════════════════════════════════════════════════════════════

function UI.setTrack(func)
	trackFunc = func
end

function UI.cleanupLoading()
	if loadingConnection then
		pcall(function() loadingConnection:Disconnect() end)
		loadingConnection = nil
	end
end

function UI.rounded(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
	return c
end

function UI.stroked(inst, alpha, color)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.stroke
	s.Thickness = 1
	s.Transparency = alpha or 0.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function UI.brighten(color, factor)
	return Color3.fromRGB(
		math.min(255, color.R * 255 * factor),
		math.min(255, color.G * 255 * factor),
		math.min(255, color.B * 255 * factor)
	)
end

function UI.hover(btn, normalColor, hoverColor)
	local enterConn = btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
	end)
	local leaveConn = btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = normalColor}):Play()
	end)
	if trackFunc then
		trackFunc(enterConn)
		trackFunc(leaveConn)
	end
end

function UI.frame(props)
	local f = Instance.new("Frame")
	f.Name = props.name or "Frame"
	f.Size = props.size or UDim2.new(1, 0, 1, 0)
	f.Position = props.pos or UDim2.new(0, 0, 0, 0)
	f.BackgroundColor3 = props.bg or THEME.card
	f.BackgroundTransparency = props.bgT or 0
	f.BorderSizePixel = 0
	f.ZIndex = props.z or 100
	f.ClipsDescendants = props.clips or false
	if props.parent then f.Parent = props.parent end
	if props.corner then UI.rounded(f, props.corner) end
	if props.stroke then UI.stroked(f, props.strokeA, props.strokeC) end
	return f
end

function UI.label(props)
	local l = Instance.new("TextLabel")
	l.Name = props.name or "Label"
	l.Size = props.size or UDim2.new(1, 0, 0, 20)
	l.Position = props.pos or UDim2.new(0, 0, 0, 0)
	l.BackgroundTransparency = 1
	l.Text = props.text or ""
	l.TextColor3 = props.color or THEME.text
	l.TextSize = props.textSize or 12
	l.Font = props.font or Enum.Font.Gotham
	l.TextXAlignment = props.alignX or Enum.TextXAlignment.Left
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	l.TextWrapped = props.wrap or false
	l.TextTruncate = props.truncate or Enum.TextTruncate.None
	l.ZIndex = props.z or 100
	if props.parent then l.Parent = props.parent end
	return l
end

function UI.button(props)
	local b = Instance.new("TextButton")
	b.Name = props.name or "Button"
	b.Size = props.size or UDim2.new(0, 100, 0, 36)
	b.Position = props.pos or UDim2.new(0, 0, 0, 0)
	b.BackgroundColor3 = props.bg or THEME.accent
	b.Text = props.text or "Button"
	b.TextColor3 = props.color or Color3.new(1, 1, 1)
	b.TextSize = props.textSize or 12
	b.Font = props.font or Enum.Font.GothamBold
	b.AutoButtonColor = false
	b.ZIndex = props.z or 100
	if props.parent then b.Parent = props.parent end
	if props.corner then UI.rounded(b, props.corner) end
	if props.hover then UI.hover(b, props.bg or THEME.accent, props.hoverBg or UI.brighten(props.bg or THEME.accent, 1.15)) end
	return b
end

function UI.input(labelText, placeholder, yPos, parent, multiLine)
	UI.label({
		size = UDim2.new(1, 0, 0, 14),
		pos = UDim2.new(0, 0, 0, yPos),
		text = labelText,
		textSize = 10,
		font = Enum.Font.GothamBold,
		z = 105,
		parent = parent
	})

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, 0, 0, multiLine and 55 or 36)
	input.Position = UDim2.new(0, 0, 0, yPos + 18)
	input.BackgroundColor3 = THEME.elevated
	input.BorderSizePixel = 0
	input.Text = ""
	input.TextColor3 = THEME.text
	input.TextSize = 12
	input.Font = Enum.Font.Gotham
	input.PlaceholderText = placeholder
	input.PlaceholderColor3 = THEME.subtle
	input.ClearTextOnFocus = false
	input.TextWrapped = multiLine or false
	input.MultiLine = multiLine or false
	input.TextYAlignment = multiLine and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
	input.ZIndex = 105
	input.Parent = parent
	UI.rounded(input, 8)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	if multiLine then pad.PaddingTop = UDim.new(0, 8) end
	pad.Parent = input

	return input
end

function UI.loading(parent)
	local container = UI.frame({size = UDim2.new(1, 0, 0, 80), bgT = 1, z = 104, parent = parent})
	local dots = {}
	for i = 1, 3 do
		dots[i] = UI.frame({
			size = UDim2.new(0, 6, 0, 6),
			pos = UDim2.new(0.5, -15 + (i-1) * 12, 0.5, -3),
			bg = THEME.accent, z = 105, parent = container, corner = 3
		})
	end

	local animIndex = 1
	if loadingConnection then pcall(function() loadingConnection:Disconnect() end) end
	loadingConnection = RunService.Heartbeat:Connect(function()
		if not container or not container.Parent then
			if loadingConnection then loadingConnection:Disconnect() end
			return
		end
		for i, dot in ipairs(dots) do
			if dot and dot.Parent then
				TweenService:Create(dot, TweenInfo.new(0.2), {
					BackgroundTransparency = (i == animIndex) and 0 or 0.6
				}):Play()
			end
		end
		animIndex = (animIndex % 3) + 1
	end)

	UI.label({
		size = UDim2.new(1, 0, 0, 18),
		pos = UDim2.new(0, 0, 0.5, 12),
		text = "Cargando...",
		color = THEME.muted, textSize = 11,
		alignX = Enum.TextXAlignment.Center, z = 105, parent = container
	})

	return container
end

-- ════════════════════════════════════════════════════════════════
-- COMPONENTES
-- ════════════════════════════════════════════════════════════════

-- Botón circular outlined (transparente + UIStroke + icono centrado)
-- Retorna btn, iconLabel
function UI.outlinedCircleBtn(parent, opts)
	local size = opts.size or 32
	local icon = opts.icon
	local theme = opts.theme or THEME
	local z = opts.zIndex or 216
	local pos = opts.position or UDim2.new(0, 0, 0, 0)
	local name = opts.name or "OutlinedBtn"

	local btn = UI.make("TextButton", {
		Size = UDim2.new(0, size, 0, size),
		Position = pos,
		BackgroundTransparency = 1,
		Text = "", BorderSizePixel = 0, AutoButtonColor = false,
		ZIndex = z, Name = name, Parent = parent,
	})
	UI.rounded(btn, size / 2)
	UI.make("UIStroke", {
		Color = theme.stroke, Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn,
	})
	local iconLabel = UI.make("ImageLabel", {
		Size = UDim2.new(0.55, 0, 0.55, 0), Position = UDim2.new(0.225, 0, 0.225, 0),
		BackgroundTransparency = 1, Image = icon or "",
		ImageColor3 = theme.dim,
		ZIndex = z + 1, Name = "IconImage", Parent = btn,
	})
	return btn, iconLabel
end

return UI