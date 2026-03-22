--[[
	═══════════════════════════════════════════════════════════
	LIKES SYSTEM - Sistema de likes y super likes
	═══════════════════════════════════════════════════════════
	Maneja likes, cooldowns y super likes
]]

local LikesSystem = {}

local Remotes, State, Config, NotificationSystem, player, SUPER_LIKE_PRODUCT_ID

function LikesSystem.init(remotes, state, config)
	Remotes = remotes
	State = state
	Config = config
	NotificationSystem = remotes.Systems.NotificationSystem
	player = remotes.Services.Player
	SUPER_LIKE_PRODUCT_ID = remotes.Systems.Configuration.SUPER_LIKE

	-- Inicializar listeners automáticamente
	LikesSystem.setupLikeListeners()
end

-- ═══════════════════════════════════════════════════════════════
-- ACCIONES
-- ═══════════════════════════════════════════════════════════════

function LikesSystem.giveLike(targetPlayer)
	if not targetPlayer or targetPlayer == player then return end

	-- Enviar al servidor directamente - es el servidor quien verifica cooldown
	Remotes.Likes.GiveLikeEvent:FireServer("GiveLike", targetPlayer.UserId)
end

function LikesSystem.giveSuperLike(targetPlayer)
	if not targetPlayer or targetPlayer == player then return end

	player:SetAttribute("SuperLikeTarget", targetPlayer.UserId)

	local success = pcall(function()
		Remotes.Likes.GiveSuperLikeEvent:FireServer("SetSuperLikeTarget", targetPlayer.UserId)
	end)

	if success then
		pcall(function()
			Remotes.Services.MarketplaceService:PromptProductPurchase(player, SUPER_LIKE_PRODUCT_ID)
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- LISTENERS
-- ═══════════════════════════════════════════════════════════════

function LikesSystem.setupLikeListeners(soundsFolder)
	if Remotes.Likes.GiveLikeEvent then
		Remotes.Likes.GiveLikeEvent.OnClientEvent:Connect(function(action, data)
			if action == "LikeSuccess" then
				if NotificationSystem then
					local targetName = State.target and State.target.DisplayName or "jugador"
					NotificationSystem:Success("Like", "Like enviado a " .. targetName .. "!", 2)
				end
				if soundsFolder and soundsFolder:FindFirstChild("Like") then
					soundsFolder.Like:Play()
				end
			elseif action == "LikeReceived" and data then
				-- Notificación personal: me dieron un like
				if NotificationSystem then
					NotificationSystem:Info("Like", "¡" .. data.Sender .. " te dio un Like!", 3)
				end
			elseif action == "Error" then
				if NotificationSystem then
					NotificationSystem:Error("Like", data or "Error al dar like", 3)
				end
				if soundsFolder and soundsFolder:FindFirstChild("Error") then
					soundsFolder.Error:Play()
				end
			end
		end)
	end

	if Remotes.Likes.GiveSuperLikeEvent then
		Remotes.Likes.GiveSuperLikeEvent.OnClientEvent:Connect(function(action, data)
			if action == "SuperLikeSuccess" then
				if soundsFolder and soundsFolder:FindFirstChild("Like") then
					soundsFolder.Like:Play()
				end
			elseif action == "LikeReceived" and data then
				-- Notificación personal: me dieron un super like
				if NotificationSystem then
					NotificationSystem:Success("Super Like", "¡" .. data.Sender .. " te dio un Super Like (+" .. tostring(data.Amount) .. ")!", 3)
				end
			end
		end)
	end
end

return LikesSystem
