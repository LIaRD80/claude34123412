-- StarsClient.client.lua
-- Клиент: строит весь GUI программно (без xml), отправляет Roll на сервер,
-- получает результат и показывает его + красивый "reveal" для редких звёзд.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local StarsConfig = require(ReplicatedStorage:WaitForChild("StarsConfig"))
local remotes = ReplicatedStorage:WaitForChild("StarsRemotes")

local rollRequest = remotes:WaitForChild("RollRequest")
local rollResult = remotes:WaitForChild("RollResult")
local equipStar = remotes:WaitForChild("EquipStar")
local inventoryUpdate = remotes:WaitForChild("InventoryUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-------------------------------------------------------------
-- Утилиты создания UI
-------------------------------------------------------------
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end

local function stroke(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Color3.fromRGB(255, 255, 255)
	s.Parent = parent
	return s
end

-------------------------------------------------------------
-- Главный ScreenGui
-------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StarsRNG"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Кнопка ROLL
local rollButton = Instance.new("TextButton")
rollButton.Name = "RollButton"
rollButton.Size = UDim2.new(0, 260, 0, 110)
rollButton.Position = UDim2.new(0.5, -130, 1, -150)
rollButton.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
rollButton.BorderSizePixel = 0
rollButton.Text = "🎲 ROLL!"
rollButton.TextSize = 52
rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rollButton.TextStrokeTransparency = 0
rollButton.TextStrokeColor3 = Color3.fromRGB(180, 100, 0)
rollButton.Font = Enum.Font.FredokaOne
rollButton.AutoButtonColor = true
rollButton.Parent = screenGui
corner(rollButton, 24)
stroke(rollButton, 4, Color3.fromRGB(255, 255, 255))

local cooldownBar = Instance.new("Frame")
cooldownBar.Name = "CooldownBar"
cooldownBar.Size = UDim2.new(1, 0, 0, 8)
cooldownBar.Position = UDim2.new(0, 0, 1, 0)
cooldownBar.AnchorPoint = Vector2.new(0, 0)
cooldownBar.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
cooldownBar.BorderSizePixel = 0
cooldownBar.Parent = rollButton
corner(cooldownBar, 4)

-- Последний результат вверху
local resultFrame = Instance.new("Frame")
resultFrame.Name = "LastResult"
resultFrame.Size = UDim2.new(0, 360, 0, 70)
resultFrame.Position = UDim2.new(0.5, -180, 0, 30)
resultFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
resultFrame.BackgroundTransparency = 0.15
resultFrame.BorderSizePixel = 0
resultFrame.Parent = screenGui
corner(resultFrame, 16)
stroke(resultFrame, 2, Color3.fromRGB(255, 255, 255))

local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, -20, 1, -10)
resultLabel.Position = UDim2.new(0, 10, 0, 5)
resultLabel.BackgroundTransparency = 1
resultLabel.Text = "Жми ROLL чтобы получить звезду!"
resultLabel.TextSize = 22
resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
resultLabel.TextStrokeTransparency = 0.4
resultLabel.Font = Enum.Font.FredokaOne
resultLabel.TextWrapped = true
resultLabel.Parent = resultFrame

-- Счётчик роллов
local rollsLabel = Instance.new("TextLabel")
rollsLabel.Size = UDim2.new(0, 200, 0, 36)
rollsLabel.Position = UDim2.new(0, 16, 0, 16)
rollsLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
rollsLabel.BackgroundTransparency = 0.15
rollsLabel.BorderSizePixel = 0
rollsLabel.Text = "Роллы: 0"
rollsLabel.TextSize = 22
rollsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
rollsLabel.Font = Enum.Font.FredokaOne
rollsLabel.Parent = screenGui
corner(rollsLabel, 12)
stroke(rollsLabel, 2, Color3.fromRGB(255, 255, 255))

-------------------------------------------------------------
-- Кнопка "Инвентарь"
-------------------------------------------------------------
local invButton = Instance.new("TextButton")
invButton.Name = "InventoryButton"
invButton.Size = UDim2.new(0, 150, 0, 50)
invButton.Position = UDim2.new(1, -170, 1, -70)
invButton.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
invButton.BorderSizePixel = 0
invButton.Text = "⭐ Звёзды"
invButton.TextSize = 24
invButton.TextColor3 = Color3.fromRGB(255, 255, 255)
invButton.Font = Enum.Font.FredokaOne
invButton.Parent = screenGui
corner(invButton, 16)
stroke(invButton, 3, Color3.fromRGB(255, 255, 255))

-- Окно инвентаря
local invFrame = Instance.new("Frame")
invFrame.Name = "InventoryFrame"
invFrame.Size = UDim2.new(0, 520, 0, 400)
invFrame.Position = UDim2.new(0.5, -260, 0.5, -200)
invFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
invFrame.BackgroundTransparency = 0.1
invFrame.BorderSizePixel = 0
invFrame.Visible = false
invFrame.Parent = screenGui
corner(invFrame, 18)
stroke(invFrame, 3, Color3.fromRGB(255, 255, 255))

local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.new(1, -20, 0, 40)
invTitle.Position = UDim2.new(0, 10, 0, 8)
invTitle.BackgroundTransparency = 1
invTitle.Text = "Твои звёзды"
invTitle.TextSize = 30
invTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
invTitle.Font = Enum.Font.FredokaOne
invTitle.Parent = invFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
closeBtn.Text = "X"
closeBtn.TextSize = 24
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.BorderSizePixel = 0
closeBtn.Parent = invFrame
corner(closeBtn, 10)

local invScroll = Instance.new("ScrollingFrame")
invScroll.Size = UDim2.new(1, -20, 1, -70)
invScroll.Position = UDim2.new(0, 10, 0, 60)
invScroll.BackgroundTransparency = 1
invScroll.BorderSizePixel = 0
invScroll.ScrollBarThickness = 6
invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
invScroll.Parent = invFrame

local invLayout = Instance.new("UIGridLayout")
invLayout.CellSize = UDim2.new(0, 150, 0, 90)
invLayout.CellPadding = UDim2.new(0, 8, 0, 8)
invLayout.SortOrder = Enum.SortOrder.LayoutOrder
invLayout.Parent = invScroll

invButton.MouseButton1Click:Connect(function()
	invFrame.Visible = not invFrame.Visible
end)
closeBtn.MouseButton1Click:Connect(function()
	invFrame.Visible = false
end)

-------------------------------------------------------------
-- Логика Roll-кнопки + кулдаун
-------------------------------------------------------------
local canRoll = true

local function startCooldown()
	canRoll = false
	cooldownBar.Size = UDim2.new(0, 0, 0, 8)
	rollButton.BackgroundColor3 = Color3.fromRGB(180, 140, 50)
	local tween = TweenService:Create(
		cooldownBar,
		TweenInfo.new(StarsConfig.RollCooldown, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(1, 0, 0, 8) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		canRoll = true
		rollButton.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	end)
end

rollButton.MouseButton1Click:Connect(function()
	if not canRoll then return end
	rollRequest:FireServer()
	startCooldown()
end)

-------------------------------------------------------------
-- Эффект "reveal" для редких звёзд
-------------------------------------------------------------
local function showReveal(star)
	local revealGui = Instance.new("Frame")
	revealGui.Size = UDim2.new(1, 0, 1, 0)
	revealGui.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	revealGui.BackgroundTransparency = 0.4
	revealGui.BorderSizePixel = 0
	revealGui.ZIndex = 50
	revealGui.Parent = screenGui

	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 480, 0, 220)
	card.Position = UDim2.new(0.5, -240, 0.5, -110)
	card.BackgroundColor3 = star.Color
	card.BorderSizePixel = 0
	card.ZIndex = 51
	card.Parent = revealGui
	corner(card, 24)
	stroke(card, 5, Color3.fromRGB(255, 255, 255))

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "✨ " .. star.Name .. " ✨"
	title.TextSize = 38
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0
	title.Font = Enum.Font.FredokaOne
	title.ZIndex = 52
	title.Parent = card

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0, 50)
	sub.Position = UDim2.new(0, 0, 0, 85)
	sub.BackgroundTransparency = 1
	sub.Text = "[" .. star.Rarity .. "] 1 из " .. star.Chance
	sub.TextSize = 28
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.TextStrokeTransparency = 0.3
	sub.Font = Enum.Font.FredokaOne
	sub.ZIndex = 52
	sub.Parent = card

	-- Анимация: появляется и пульсирует, потом исчезает
	card.Size = UDim2.new(0, 0, 0, 0)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	TweenService:Create(
		card,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 480, 0, 220), Position = UDim2.new(0.5, -240, 0.5, -110) }
	):Play()

	task.delay(2.5, function()
		TweenService:Create(card, TweenInfo.new(0.4), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),
		}):Play()
		TweenService:Create(revealGui, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		revealGui:Destroy()
	end)
end

-------------------------------------------------------------
-- Обработка результата ролла
-------------------------------------------------------------
rollResult.OnClientEvent:Connect(function(payload)
	local star = StarsConfig.GetById(payload.Id)
	if not star then return end

	local rarityColor = StarsConfig.RarityColors[star.Rarity] or Color3.fromRGB(255, 255, 255)

	resultLabel.Text = star.Name .. "  •  [" .. star.Rarity .. "] 1 из " .. star.Chance
	resultFrame.BackgroundColor3 = rarityColor
	resultFrame.BackgroundTransparency = 0.15

	rollsLabel.Text = "Роллы: " .. payload.TotalRolls

	-- Reveal только для редкостей Legendary и выше
	if star.Chance >= 1000 then
		showReveal(star)
	end
end)

-------------------------------------------------------------
-- Рендер инвентаря
-------------------------------------------------------------
local currentEquipped = nil

local function renderInventory(payload)
	-- Очистим
	for _, child in ipairs(invScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	currentEquipped = payload.Equipped

	-- Сортируем по редкости (от Chance возрастания)
	local items = payload.Inventory
	table.sort(items, function(a, b)
		local sa = StarsConfig.GetById(a.Id)
		local sb = StarsConfig.GetById(b.Id)
		if not sa or not sb then return false end
		return sa.Chance < sb.Chance
	end)

	for _, item in ipairs(items) do
		local star = StarsConfig.GetById(item.Id)
		if star then
			local card = Instance.new("Frame")
			card.BackgroundColor3 = star.Color
			card.BorderSizePixel = 0
			card.Parent = invScroll
			corner(card, 12)
			local isEquipped = (payload.Equipped == star.Id)
			stroke(card, isEquipped and 4 or 2,
				isEquipped and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 255, 255))

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(1, -8, 0, 26)
			name.Position = UDim2.new(0, 4, 0, 4)
			name.BackgroundTransparency = 1
			name.Text = star.Name
			name.TextSize = 16
			name.TextColor3 = Color3.fromRGB(255, 255, 255)
			name.TextStrokeTransparency = 0.3
			name.Font = Enum.Font.FredokaOne
			name.TextWrapped = true
			name.Parent = card

			local count = Instance.new("TextLabel")
			count.Size = UDim2.new(1, -8, 0, 20)
			count.Position = UDim2.new(0, 4, 0, 32)
			count.BackgroundTransparency = 1
			count.Text = "x" .. item.Count .. " • 1/" .. star.Chance
			count.TextSize = 14
			count.TextColor3 = Color3.fromRGB(255, 255, 255)
			count.Font = Enum.Font.GothamBold
			count.Parent = card

			local equipBtn = Instance.new("TextButton")
			equipBtn.Size = UDim2.new(1, -8, 0, 26)
			equipBtn.Position = UDim2.new(0, 4, 1, -30)
			equipBtn.BackgroundColor3 = isEquipped
				and Color3.fromRGB(220, 200, 60)
				or Color3.fromRGB(60, 60, 100)
			equipBtn.BorderSizePixel = 0
			equipBtn.Text = isEquipped and "Снять" or "Надеть"
			equipBtn.TextSize = 14
			equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			equipBtn.Font = Enum.Font.FredokaOne
			equipBtn.Parent = card
			corner(equipBtn, 8)

			equipBtn.MouseButton1Click:Connect(function()
				if isEquipped then
					equipStar:FireServer(nil)
				else
					equipStar:FireServer(star.Id)
				end
			end)
		end
	end

	invScroll.CanvasSize = UDim2.new(0, 0, 0, invLayout.AbsoluteContentSize.Y + 12)
end

inventoryUpdate.OnClientEvent:Connect(renderInventory)
