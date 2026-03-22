local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Players           = game:GetService("Players")

local uxrRS          = ReplicatedStorage["RanksOverHead"]
local overheadEvents = uxrRS.overheadEvents
local LocalPlayer    = Players.LocalPlayer
local Character      = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- AFK
UserInputService.WindowFocused:Connect(function()
	overheadEvents.RemoteEvent:FireServer("DisableAFK")
end)
UserInputService.WindowFocusReleased:Connect(function()
	overheadEvents.RemoteEvent:FireServer("EnableAFK")
end)

