local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("UI"))
local THEME = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThemeConfig"))

local SearchModern = {}

-- options: {placeholder, onSearch (fn), size (UDim2), bg, corner, z}

function SearchModern.new(parent, options)
	options = options or {}
	local placeholder = options.placeholder or "Buscar..."
	local onSearch = options.onSearch
	local size = options.size or UDim2.new(1, 0, 0, 36)
	local bg = options.bg or THEME.card
	local corner = options.corner or 8
	local z = options.z or 100
	local isMobile = options.isMobile
	local inputName = options.inputName or "SearchInput"

	local container = UI.frame({size = size, bg = bg, parent = parent, corner = corner, z = z})

	-- Icon container (círculo + línea)
	local iconWidth = options.isMobile and 20 or 26
	local iconOffset = options.isMobile and 4 or 6

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "SearchIconContainer"
	iconContainer.Size = UDim2.new(0, iconWidth, 1, 0)
	iconContainer.Position = UDim2.new(0, iconOffset, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = z + 1
	iconContainer.Parent = container

	local circleSize = options.isMobile and 10 or 12
	local circle = Instance.new("Frame")
	circle.Name = "SearchCircle"
	circle.Size = UDim2.new(0, circleSize, 0, circleSize)
	circle.Position = UDim2.new(0.5, options.isMobile and -6 or -7, 0.5, options.isMobile and -6 or -7)
	circle.BackgroundTransparency = 1
	circle.Parent = iconContainer
	UI.rounded(circle, circleSize)
	local circleStroke = Instance.new("UIStroke")
	circleStroke.Color = THEME.subtle
	circleStroke.Thickness = options.isMobile and 1.5 or 2
	circleStroke.Transparency = 0.3
	circleStroke.Parent = circle

	local handle = Instance.new("Frame")
	handle.Name = "SearchHandle"
	handle.Size = UDim2.new(0, options.isMobile and 5 or 6, 0, options.isMobile and 1.5 or 2)
	handle.Position = UDim2.new(0.5, options.isMobile and 2 or 3, 0.5, options.isMobile and 3 or 4)
	handle.Rotation = 45
	handle.BackgroundColor3 = THEME.subtle
	handle.BackgroundTransparency = 0.3
	handle.BorderSizePixel = 0
	handle.ZIndex = z + 1
	handle.Parent = iconContainer
	UI.rounded(handle, 2)

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, options.isMobile and -28 or -44, 1, 0)
	input.Position = UDim2.new(0, options.isMobile and 24 or 40, 0, 0)
	input.BackgroundTransparency = 1
	input.Text = ""
	input.Name = inputName
	input.ClearTextOnFocus = false
	input.PlaceholderText = placeholder
	input.PlaceholderColor3 = THEME.subtle
	input.TextColor3 = THEME.text
	input.TextSize = options.textSize or (options.isMobile and 13 or 13)
	input.Font = Enum.Font.Gotham
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.ZIndex = z + 1
	input.Parent = container

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = container

	-- Focus animations (color/alpha)
	local function onFocus()
		pcall(function()
			circleStroke.Color = THEME.accent
			circleStroke.Transparency = 0
			handle.BackgroundColor3 = THEME.accent
			handle.BackgroundTransparency = 0
		end)
	end

	local function onBlur()
		pcall(function()
			circleStroke.Color = THEME.subtle
			circleStroke.Transparency = 0.3
			handle.BackgroundColor3 = THEME.subtle
			handle.BackgroundTransparency = 0.3
		end)
	end

	input.Focused:Connect(onFocus)
	input.FocusLost:Connect(onBlur)

	local debounce = false
	input:GetPropertyChangedSignal("Text"):Connect(function()
		if debounce then return end
		debounce = true
		local txt = input.Text
		task.delay(0.28, function()
			if onSearch then
				pcall(onSearch, txt)
			end
			debounce = false
		end)
	end)

	return container, input
end

return SearchModern
