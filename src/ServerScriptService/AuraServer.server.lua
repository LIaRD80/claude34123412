-- AuraServer.server.lua
-- Показывает экипированную звезду как ауру (PointLight + ParticleEmitter)
-- вокруг персонажа. Слушает изменения через InventoryUpdate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StarsConfig = require(ReplicatedStorage:WaitForChild("StarsConfig"))
local remotes = ReplicatedStorage:WaitForChild("StarsRemotes")
local inventoryUpdate = remotes:WaitForChild("InventoryUpdate")

local equippedByPlayer = {} -- [player] = starId

local function clearAura(character)
	local existing = character:FindFirstChild("StarAura")
	if existing then existing:Destroy() end
end

local function applyAura(character, star)
	clearAura(character)
	if not star then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local aura = Instance.new("Attachment")
	aura.Name = "StarAura"
	aura.Parent = root

	local light = Instance.new("PointLight")
	light.Color = star.GlowColor
	light.Brightness = 3
	light.Range = 14
	light.Parent = aura

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(star.Color, star.GlowColor)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.7
	emitter.Parent = aura
end

local function refreshFor(player)
	local starId = equippedByPlayer[player]
	local star = starId and StarsConfig.GetById(starId) or nil
	local character = player.Character
	if character then
		applyAura(character, star)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)
		refreshFor(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	equippedByPlayer[player] = nil
end)

-- Слушаем серверный апдейт инвентаря и копируем эту инфу через тот же event клиенту.
-- Чтобы не дублировать каналы, используем серверный side: подменим обработку.
-- (Сервер сам шлёт InventoryUpdate; локально перехватим через BindableEvent? — нет.
-- Проще: дублируем логику equip через дополнительный обработчик.)

-- Слушаем equip напрямую: добавим обработчик equipStar.OnServerEvent тут же,
-- но т.к. сервер уже его слушает в StarsServer — используем "Changed" нельзя.
-- Решение: StarsServer пишет ServerStorage-флаг? Слишком сложно для MVP.
-- Сделаем так: дополнительно слушаем equipStar и здесь — оба обработчика
-- спокойно сосуществуют (RemoteEvent поддерживает несколько подключений).

local equipStar = remotes:WaitForChild("EquipStar")
equipStar.OnServerEvent:Connect(function(player, starId)
	if starId ~= nil and type(starId) ~= "string" then return end
	if starId ~= nil and not StarsConfig.GetById(starId) then return end
	equippedByPlayer[player] = starId
	refreshFor(player)
end)
