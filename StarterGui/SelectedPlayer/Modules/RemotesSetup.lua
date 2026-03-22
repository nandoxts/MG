--[[
	═══════════════════════════════════════════════════════════
	REMOTES SETUP - Inicialización de servicios y remotes
	═══════════════════════════════════════════════════════════
	Setup centralizado de todos los servicios y remotes
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

return function()
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 2)
	local mouse = player:GetMouse()
	local camera = workspace.CurrentCamera

	-- Remotes folder
	local remoteGlobal = ReplicatedStorage:FindFirstChild("RemotesGlobal") or ReplicatedStorage:WaitForChild("RemotesGlobal", 2)
	local remotesFolder = remoteGlobal:FindFirstChild("UserPanel") or remoteGlobal:WaitForChild("UserPanel", 2)

	-- Sistema de sincronización
	local RemotesSync = remoteGlobal:FindFirstChild("Emotes_Sync")

	-- Sistema de likes
	local LikesEvents = remoteGlobal:WaitForChild("LikesEvents")

	-- Sistema de SelectedPlayer
	local SelectedPlayerModule = remoteGlobal:FindFirstChild("SelectedPlayer")

	-- GlobalModalManager
	local GlobalModalManager = nil
	pcall(function()
		local Systems = ReplicatedStorage:FindFirstChild("Systems") or ReplicatedStorage:WaitForChild("Systems", 2)
		GlobalModalManager = require(Systems:FindFirstChild("GlobalModalManager") or Systems:WaitForChild("GlobalModalManager", 2))
	end)

	-- NotificationSystem
	local NotificationSystem = nil
	pcall(function()
		local Systems = ReplicatedStorage:FindFirstChild("Systems") or ReplicatedStorage:WaitForChild("Systems", 2)
		local NotifSys = Systems:FindFirstChild("NotificationSystem") or Systems:WaitForChild("NotificationSystem", 2)
		local NotifModule = NotifSys:FindFirstChild("NotificationSystem") or NotifSys:WaitForChild("NotificationSystem", 2)
		NotificationSystem = require(NotifModule)
	end)

	-- ColorEffects
	local Highlight = SelectedPlayerModule and SelectedPlayerModule:FindFirstChild("Highlight")
	local ColorEffects = ReplicatedStorage:FindFirstChild("Config") and require(ReplicatedStorage.Config.ColorConfig) or nil


	-- Configuration
	local Configuration = {}
	pcall(function()
		local configModule = ReplicatedStorage:FindFirstChild("Config") or ReplicatedStorage:WaitForChild("Config", 2)
		local configFile = configModule:FindFirstChild("Configuration") or configModule:WaitForChild("Configuration", 5)
		if configFile then Configuration = require(configFile) end
	end)

	return {
		-- Servicios
		Services = {
			Players = Players,
			PlayerGui = playerGui,
			Mouse = mouse,
			Camera = camera,
			ReplicatedStorage = ReplicatedStorage,
			MarketplaceService = MarketplaceService,
			TweenService = TweenService,
			GuiService = GuiService,
			UserInputService = UserInputService,
			RunService = RunService,
			TextChatService = TextChatService,
			Player = player
		},

		-- Remotes de UserPanel
		Remotes = {
			GetUserData      = remotesFolder:WaitForChild("GetUserData"),
			GetUserDonations = remotesFolder:WaitForChild("GetUserDonations"),
			DonationNotify   = remotesFolder:FindFirstChild("DonationNotify"),
			DonationMessage  = remotesFolder:FindFirstChild("DonationMessage"),
			CheckGamePass    = remotesFolder:WaitForChild("CheckGamePass")
		},

		-- Sistema de Sync
		Sync = {
			SyncRemote = RemotesSync and RemotesSync:FindFirstChild("Sync"),
			GetSyncState = RemotesSync and RemotesSync:FindFirstChild("GetSyncState"),
			SyncUpdate = RemotesSync and RemotesSync:FindFirstChild("SyncUpdate")
		},

		-- Sistema de Likes
		Likes = {
			GiveLikeEvent = LikesEvents and (LikesEvents:FindFirstChild("GiveLikeEvent") or LikesEvents:WaitForChild("GiveLikeEvent", 2)),
			GiveSuperLikeEvent = LikesEvents and (LikesEvents:FindFirstChild("GiveSuperLikeEvent") or LikesEvents:WaitForChild("GiveSuperLikeEvent", 2))
		},

		-- Sistemas
		Systems = {
			GlobalModalManager = GlobalModalManager,
			NotificationSystem = NotificationSystem,
			ColorEffects = ColorEffects,
			Configuration = Configuration
		}
	}
end
