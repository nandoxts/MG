local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerScripts = player.PlayerScripts

-- Wait for character to load
repeat
	task.wait(1)
until player.Character and player.CharacterAppearanceLoaded

-- Wait for CoreScripts to be ready
local function waitForCoreScript()
	local success = false
	local attempts = 0
	local maxAttempts = 30 -- 30 second timeout

	repeat
		attempts = attempts + 1
		success = pcall(function()
			StarterGui:SetCore("AvatarContextMenuEnabled", true)
		end)

		if not success then
			task.wait(1)
		end
	until success or attempts >= maxAttempts

	return success
end

-- Only proceed if CoreScript is ready
if waitForCoreScript() then
	-- Configure the avatar context menu
	StarterGui:SetCore("RemoveAvatarContextMenuOption", Enum.AvatarContextMenuOption.Emote)
	StarterGui:SetCore("AvatarContextMenuTheme", {
		BackgroundImage = "",
		BackgroundTransparency = 0.3,
		BackgroundColor = Color3.fromRGB(40, 37, 37),
		NameTagColor = Color3.fromRGB(40, 37, 37),
		NameUnderlineColor = Color3.fromRGB(40, 37, 37),
		ButtonFrameColor = Color3.fromRGB(40, 37, 37),
		ButtonFrameTransparency = 0.3,
		ButtonUnderlineColor = Color3.fromRGB(40, 37, 37),
		Font = Enum.Font.Jura
	})

	-- Create bindable events
	local be = Instance.new("BindableEvent") 
	local unsyncBe = Instance.new("BindableEvent") 

	-- Remotes del sistema nuevo (Emotes_Sync)
	local RemotesGlobal = ReplicatedStorage:WaitForChild("RemotesGlobal")
	local EmotesSync = RemotesGlobal:WaitForChild("Emotes_Sync")
	local SyncRemote = EmotesSync:WaitForChild("Sync")

	-- Define functions
	local function resolveContextTarget(rawTarget)
		if typeof(rawTarget) == "Instance" and rawTarget:IsA("Player") then
			return rawTarget
		end

		if typeof(rawTarget) == "number" then
			return Players:GetPlayerByUserId(rawTarget) or rawTarget
		end

		if typeof(rawTarget) == "string" then
			local asUserId = tonumber(rawTarget)
			if asUserId then
				return Players:GetPlayerByUserId(asUserId) or asUserId
			end
			return rawTarget
		end

		return rawTarget
	end

	local function sync(t)
		SyncRemote:FireServer("sync", resolveContextTarget(t))
	end

	local function unsync()
		SyncRemote:FireServer("unsync")
	end

	-- Connect events
	be.Event:Connect(sync) 
	unsyncBe.Event:Connect(unsync) 

	-- Add context menu options
	StarterGui:SetCore("AddAvatarContextMenuOption", {"Sync Current Dance", be}) 
	StarterGui:SetCore("AddAvatarContextMenuOption", {"Unsync Dance", unsyncBe}) 
else
	warn("Avatar Context Menu CoreScript failed to load within timeout period")
end