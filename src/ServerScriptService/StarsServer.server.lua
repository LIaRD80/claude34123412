-- StarsServer.server.lua
-- Серверная логика: создаёт RemoteEvent'ы, обрабатывает запросы Roll,
-- хранит инвентарь игрока в сессии и применяет анти-флуд кулдаун.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StarsConfig = require(ReplicatedStorage:WaitForChild("StarsConfig"))

-- Папка для всех Remote'ов
local remotesFolder = ReplicatedStorage:FindFirstChild("StarsRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "StarsRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function makeRemote(class, name)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = remotesFolder
	return r
end

local rollRequest = makeRemote("RemoteEvent", "RollRequest")
local rollResult = makeRemote("RemoteEvent", "RollResult")
local equipStar = makeRemote("RemoteEvent", "EquipStar")
local inventoryUpdate = makeRemote("RemoteEvent", "InventoryUpdate")

-- Данные игроков в памяти (для MVP без DataStore)
local playerData = {}

local function newPlayerData()
	return {
		lastRoll = 0,
		totalRolls = 0,
		inventory = {}, -- [starId] = count
		equipped = nil, -- starId
	}
end

-- Выбор звезды по шансам.
-- Идём от самой редкой к самой частой и катим math.random(1, Chance).
-- Если выпадает 1 — даём эту звезду. Иначе берём базовую (Common).
local function pickStar()
	local sorted = {}
	for i, star in ipairs(StarsConfig.Stars) do
		sorted[i] = star
	end
	table.sort(sorted, function(a, b)
		return a.Chance > b.Chance
	end)

	for _, star in ipairs(sorted) do
		if math.random(1, star.Chance) == 1 then
			return star
		end
	end
	return sorted[#sorted] -- самая частая
end

local function buildInventoryPayload(data)
	local list = {}
	for starId, count in pairs(data.inventory) do
		table.insert(list, { Id = starId, Count = count })
	end
	return {
		Inventory = list,
		Equipped = data.equipped,
		TotalRolls = data.totalRolls,
	}
end

Players.PlayerAdded:Connect(function(player)
	playerData[player] = newPlayerData()
	-- Небольшая задержка на загрузку клиента
	task.delay(2, function()
		if player.Parent then
			inventoryUpdate:FireClient(player, buildInventoryPayload(playerData[player]))
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)

rollRequest.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	local now = tick()
	if now - data.lastRoll < StarsConfig.RollCooldown then
		return -- анти-спам
	end
	data.lastRoll = now
	data.totalRolls = data.totalRolls + 1

	local star = pickStar()
	data.inventory[star.Id] = (data.inventory[star.Id] or 0) + 1

	rollResult:FireClient(player, {
		Id = star.Id,
		TotalRolls = data.totalRolls,
	})

	inventoryUpdate:FireClient(player, buildInventoryPayload(data))
end)

equipStar.OnServerEvent:Connect(function(player, starId)
	local data = playerData[player]
	if not data then return end
	if starId ~= nil and type(starId) ~= "string" then return end

	if starId == nil then
		data.equipped = nil
	elseif data.inventory[starId] and data.inventory[starId] > 0 then
		data.equipped = starId
	else
		return
	end

	inventoryUpdate:FireClient(player, buildInventoryPayload(data))
end)
