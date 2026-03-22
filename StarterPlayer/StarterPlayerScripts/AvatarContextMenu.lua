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
	local GetSyncState = EmotesSync:WaitForChild("GetSyncState")

	-- NotificationSystem
	local NotificationSystem
	pcall(function()
		NotificationSystem = require(
			ReplicatedStorage:WaitForChild("Systems")
				:WaitForChild("NotificationSystem")
				:WaitForChild("NotificationSystem")
		)
	end)

	-- Define functions
	local function sync(t)
		-- Validación: no sincronizarse consigo mismo
		if not t or t == player then
			if NotificationSystem then
				NotificationSystem:Warning("Sync", "No puedes sincronizarte contigo mismo", 3)
			end
			return
		end

		-- Consultar estado actual
		local ok, syncInfo = pcall(function()
			return GetSyncState:InvokeServer()
		end)

		if not ok then
			if NotificationSystem then
				NotificationSystem:Error("Sync", "Error al consultar sincronización", 3)
			end
			return
		end

		-- Si ya estoy sincronizado, desincronizar primero
		if syncInfo and syncInfo.isSynced then
			SyncRemote:FireServer("unsync")
			task.wait(0.1)
		end

		-- Sincronizar con el nuevo jugador
		SyncRemote:FireServer("sync", t)
	end

	local function unsync()
		SyncRemote:FireServer("unsync")
		if NotificationSystem then
			NotificationSystem:Info("Sync", "Has dejado de estar sincronizado", 4)
		end
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