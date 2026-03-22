local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = {}

-- Lista de admins por nombre de usuario ONLY (sin UserIds)
AdminConfig.AdminUserNames = {
	"ignxts","AdrienPCxx","ACarolina3098","Honored092", "Xandroquis","laykanini","Kttynaru",
}

-- Acepta un Instance (Player) o un string (nombre)
function AdminConfig:IsAdmin(playerOrName)
	local name
	if typeof(playerOrName) == "Instance" and playerOrName.Name then
		name = playerOrName.Name
	elseif type(playerOrName) == "string" then
		name = playerOrName
	else
		return false
	end
	if not name then return false end
	return table.find(self.AdminUserNames, name) ~= nil
end

return AdminConfig
