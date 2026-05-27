-- StarsClient.client.lua
-- Клиент Stars RNG. UI ты собираешь сам в StarterGui, скрипт находит элементы по имени.
--
-- Ожидаемая структура внутри PlayerGui (=твой StarterGui):
--
--   ScreenGui (имя: "StarsGui")
--   ├── RollButton        (TextButton)  — обязательно
--   │   └── CooldownBar   (Frame)       — опционально, его Size.X.Scale тянется 0→1
--   ├── RollsLabel        (TextLabel)   — опционально, текст: "Роллы: 12"
--   ├── ResultLabel       (TextLabel)   — опционально, текст: "Сверхновая • Mythic • 1/10000"
--   ├── InventoryButton   (TextButton)  — опционально, открывает/закрывает InventoryFrame
--   ├── InventoryFrame    (Frame)       — опционально, скрытое окно инвентаря
--   │   └── InventoryList (ScrollingFrame или Frame с UIGridLayout) — куда падают карточки звёзд
--   │       └── ItemTemplate (Frame)    — опционально шаблон карточки; если нет — будет дефолтный
--   │
--   (Reel-оверлей скрипт создаёт сам, тебе делать его не надо)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local StarsConfig = require(ReplicatedStorage:WaitForChild("StarsConfig"))
local remotes = ReplicatedStorage:WaitForChild("StarsRemotes")

local rollRequest = remotes:WaitForChild("RollRequest")
local rollResult = remotes:WaitForChild("RollResult")
local equipStar = remotes:WaitForChild("EquipStar")
local inventoryUpdate = remotes:WaitForChild("InventoryUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-------------------------------------------------------------
-- Находим твой GUI и его элементы
-------------------------------------------------------------
local screenGui = playerGui:WaitForChild("StarsGui", 30)
if not screenGui then
	warn("[StarsRNG] В PlayerGui не нашлось ScreenGui 'StarsGui'. Создай его в StarterGui.")
	return
end

-- Ищем элементы рекурсивно (на любой глубине) — чтобы можно было разложить как угодно.
local function findDescendant(root, name)
	if not root then return nil end
	local direct = root:FindFirstChild(name)
	if direct then return direct end
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name then return d end
	end
	return nil
end

local rollButton = findDescendant(screenGui, "RollButton")
if not rollButton or not rollButton:IsA("GuiButton") then
	warn("[StarsRNG] Не нашёл TextButton с именем 'RollButton' внутри StarsGui.")
	return
end

local cooldownBar = findDescendant(rollButton, "CooldownBar")
local rollsLabel = findDescendant(screenGui, "RollsLabel")
local resultLabel = findDescendant(screenGui, "ResultLabel")
local inventoryButton = findDescendant(screenGui, "InventoryButton")
local inventoryFrame = findDescendant(screenGui, "InventoryFrame")
local inventoryList = findDescendant(screenGui, "InventoryList")
local itemTemplate = inventoryList and inventoryList:FindFirstChild("ItemTemplate")
if itemTemplate then
	itemTemplate.Visible = false
end

-------------------------------------------------------------
-- Лента прокрутки (CS:GO-style): создаётся скриптом
-------------------------------------------------------------
local REEL_WIDTH = 720
local REEL_HEIGHT = 160
local CARD_WIDTH = 140
local CARD_COUNT = 60
local WINNING_INDEX = 54 -- ближе к концу ленты, чтобы было длинное торможение
local REEL_DURATION = 4.0

-- "Взвешенный" пул для случайных карточек на ленте:
-- чаще показываем обычные звёзды, реже редкие.
-- Веса вычисляем как inverse от Chance (чем реже звезда, тем меньше шанс быть в ленте).
local reelWeights = {}
local totalWeight = 0
do
	for _, star in ipairs(StarsConfig.Stars) do
		local w = math.max(1, math.floor(100 / math.sqrt(star.Chance)))
		reelWeights[#reelWeights + 1] = { star = star, weight = w }
		totalWeight = totalWeight + w
	end
end

local function pickReelStar()
	local r = math.random(1, totalWeight)
	local acc = 0
	for _, entry in ipairs(reelWeights) do
		acc = acc + entry.weight
		if r <= acc then
			return entry.star
		end
	end
	return reelWeights[1].star
end

local function newCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function newStroke(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = color or Color3.fromRGB(255, 255, 255)
	s.Parent = parent
end

local function buildCard(star, index)
	local card = Instance.new("Frame")
	card.Name = "Card_" .. index
	card.Size = UDim2.new(0, CARD_WIDTH - 12, 1, -24)
	card.Position = UDim2.new(0, (index - 1) * CARD_WIDTH + 6, 0, 12)
	card.BackgroundColor3 = star.Color
	card.BorderSizePixel = 0
	card.ZIndex = 102
	newCorner(card, 10)
	newStroke(card, 2, Color3.fromRGB(255, 255, 255))

	-- Подсветка-градиент
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(star.GlowColor, star.Color)
	gradient.Rotation = 90
	gradient.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -8, 0, 30)
	nameLabel.Position = UDim2.new(0, 4, 1, -36)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = star.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.ZIndex = 104
	nameLabel.Parent = card

	-- "Звезда" — простой текстовый символ ★
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 70)
	icon.Position = UDim2.new(0, 0, 0, 8)
	icon.BackgroundTransparency = 1
	icon.Text = "★"
	icon.TextColor3 = Color3.fromRGB(255, 255, 255)
	icon.TextStrokeTransparency = 0.2
	icon.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	icon.Font = Enum.Font.FredokaOne
	icon.TextScaled = true
	icon.ZIndex = 103
	icon.Parent = card

	return card
end

local reelInProgress = false

local function playReel(winningStar, onLand)
	if reelInProgress then return end
	reelInProgress = true

	-- Полупрозрачная подложка
	local overlay = Instance.new("Frame")
	overlay.Name = "ReelOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 100
	overlay.Parent = screenGui

	-- Каркас ленты
	local reelFrame = Instance.new("Frame")
	reelFrame.Size = UDim2.new(0, REEL_WIDTH, 0, REEL_HEIGHT)
	reelFrame.Position = UDim2.new(0.5, -REEL_WIDTH / 2, 0.5, -REEL_HEIGHT / 2)
	reelFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
	reelFrame.BorderSizePixel = 0
	reelFrame.ClipsDescendants = true
	reelFrame.ZIndex = 101
	reelFrame.Parent = overlay
	newCorner(reelFrame, 16)
	newStroke(reelFrame, 4, Color3.fromRGB(255, 220, 60))

	-- Заголовок над лентой
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 400, 0, 40)
	title.Position = UDim2.new(0.5, -200, 0.5, -REEL_HEIGHT / 2 - 56)
	title.BackgroundTransparency = 1
	title.Text = "Открываем звезду..."
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 32
	title.ZIndex = 101
	title.Parent = overlay

	-- Контент ленты — длинная горизонтальная полоса карточек
	local content = Instance.new("Frame")
	content.Name = "ReelContent"
	content.Size = UDim2.new(0, CARD_WIDTH * CARD_COUNT, 1, 0)
	content.Position = UDim2.new(0, 0, 0, 0)
	content.BackgroundTransparency = 1
	content.ZIndex = 102
	content.Parent = reelFrame

	local winningCard
	for i = 1, CARD_COUNT do
		local star
		if i == WINNING_INDEX then
			star = winningStar
		else
			star = pickReelStar()
		end
		local card = buildCard(star, i)
		card.Parent = content
		if i == WINNING_INDEX then
			winningCard = card
		end
	end

	-- Центральная "стрелка"-указатель
	local pointer = Instance.new("Frame")
	pointer.Size = UDim2.new(0, 4, 1, 20)
	pointer.Position = UDim2.new(0.5, -2, 0, -10)
	pointer.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
	pointer.BorderSizePixel = 0
	pointer.ZIndex = 105
	pointer.Parent = reelFrame
	newCorner(pointer, 2)

	local pointerTopArrow = Instance.new("TextLabel")
	pointerTopArrow.Size = UDim2.new(0, 30, 0, 30)
	pointerTopArrow.Position = UDim2.new(0.5, -15, 0, -28)
	pointerTopArrow.BackgroundTransparency = 1
	pointerTopArrow.Text = "▼"
	pointerTopArrow.TextColor3 = Color3.fromRGB(255, 220, 60)
	pointerTopArrow.TextStrokeTransparency = 0.3
	pointerTopArrow.Font = Enum.Font.FredokaOne
	pointerTopArrow.TextSize = 28
	pointerTopArrow.ZIndex = 106
	pointerTopArrow.Parent = reelFrame

	-- Сколько пикселей сместить, чтобы центр победной карточки
	-- встал ровно под указатель (центр ленты).
	local targetX = REEL_WIDTH / 2 - ((WINNING_INDEX - 1) * CARD_WIDTH + CARD_WIDTH / 2)

	-- Звук-тиканье на каждой карточке (опционально, без ассета молчит)
	-- Можешь подложить свой Sound в SoundService и слушать здесь его айди.

	-- Появление: легкое масштабирование ленты
	reelFrame.Size = UDim2.new(0, 0, 0, REEL_HEIGHT)
	reelFrame.Position = UDim2.new(0.5, 0, 0.5, -REEL_HEIGHT / 2)
	TweenService:Create(
		reelFrame,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(0, REEL_WIDTH, 0, REEL_HEIGHT),
			Position = UDim2.new(0.5, -REEL_WIDTH / 2, 0.5, -REEL_HEIGHT / 2),
		}
	):Play()

	-- Основной "ролл" — едет, замедляется (Quint Out)
	local mainTween = TweenService:Create(
		content,
		TweenInfo.new(REEL_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, targetX, 0, 0) }
	)
	mainTween:Play()

	mainTween.Completed:Connect(function()
		-- Маленький "буст" в победную карточку: пульс-увеличение
		if winningCard then
			local origSize = winningCard.Size
			local origPos = winningCard.Position
			local cx = origPos.X.Offset + (CARD_WIDTH - 12) / 2
			local cy = origPos.Y.Offset + (REEL_HEIGHT - 24) / 2

			TweenService:Create(
				winningCard,
				TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{
					Size = UDim2.new(0, CARD_WIDTH + 10, 1, -6),
					Position = UDim2.new(0, cx - (CARD_WIDTH + 10) / 2, 0, cy - (REEL_HEIGHT - 6) / 2),
				}
			):Play()

			local glow = Instance.new("UIStroke")
			glow.Thickness = 0
			glow.Color = Color3.fromRGB(255, 255, 255)
			glow.Transparency = 0
			glow.Parent = winningCard
			TweenService:Create(glow, TweenInfo.new(0.5), { Thickness = 8, Transparency = 0.6 }):Play()
		end

		title.Text = "🎉 " .. winningStar.Name .. " 🎉"

		-- Через 1.5 сек — затухание
		task.delay(1.5, function()
			TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(reelFrame, TweenInfo.new(0.4), {
				Size = UDim2.new(0, REEL_WIDTH, 0, 0),
				Position = UDim2.new(0.5, -REEL_WIDTH / 2, 0.5, 0),
			}):Play()
			TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.5)
			overlay:Destroy()
			reelInProgress = false
			if onLand then onLand() end
		end)
	end)
end

-------------------------------------------------------------
-- Кулдаун на кнопке
-------------------------------------------------------------
local canRoll = true

local function startCooldown()
	canRoll = false
	if cooldownBar then
		cooldownBar.Size = UDim2.new(0, 0, cooldownBar.Size.Y.Scale, cooldownBar.Size.Y.Offset)
		local tween = TweenService:Create(
			cooldownBar,
			TweenInfo.new(StarsConfig.RollCooldown, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(1, 0, cooldownBar.Size.Y.Scale, cooldownBar.Size.Y.Offset) }
		)
		tween:Play()
	end
	rollButton.AutoButtonColor = false
	task.delay(StarsConfig.RollCooldown, function()
		canRoll = true
		rollButton.AutoButtonColor = true
	end)
end

rollButton.MouseButton1Click:Connect(function()
	if not canRoll or reelInProgress then return end
	rollRequest:FireServer()
	startCooldown()
end)

-------------------------------------------------------------
-- Результат ролла → показываем ленту → обновляем лейблы
-------------------------------------------------------------
rollResult.OnClientEvent:Connect(function(payload)
	local star = StarsConfig.GetById(payload.Id)
	if not star then return end

	playReel(star, function()
		if resultLabel then
			resultLabel.Text = string.format("%s • %s • 1 из %d", star.Name, star.Rarity, star.Chance)
			local rarityColor = StarsConfig.RarityColors[star.Rarity]
			if rarityColor and resultLabel:IsA("TextLabel") then
				resultLabel.TextColor3 = rarityColor
			end
		end
		if rollsLabel then
			rollsLabel.Text = "Роллы: " .. payload.TotalRolls
		end
	end)
end)

-------------------------------------------------------------
-- Инвентарь (если ты сделал InventoryList в StarterGui)
-------------------------------------------------------------
local function makeDefaultCard()
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 150, 0, 90)
	card.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
	card.BorderSizePixel = 0
	newCorner(card, 10)
	newStroke(card, 2, Color3.fromRGB(255, 255, 255))

	local name = Instance.new("TextLabel")
	name.Name = "NameLabel"
	name.Size = UDim2.new(1, -8, 0, 24)
	name.Position = UDim2.new(0, 4, 0, 4)
	name.BackgroundTransparency = 1
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.3
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 16
	name.Parent = card

	local count = Instance.new("TextLabel")
	count.Name = "CountLabel"
	count.Size = UDim2.new(1, -8, 0, 20)
	count.Position = UDim2.new(0, 4, 0, 30)
	count.BackgroundTransparency = 1
	count.TextColor3 = Color3.fromRGB(255, 255, 255)
	count.Font = Enum.Font.GothamBold
	count.TextSize = 14
	count.Parent = card

	local equip = Instance.new("TextButton")
	equip.Name = "EquipButton"
	equip.Size = UDim2.new(1, -8, 0, 26)
	equip.Position = UDim2.new(0, 4, 1, -30)
	equip.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
	equip.BorderSizePixel = 0
	equip.Font = Enum.Font.FredokaOne
	equip.TextSize = 14
	equip.TextColor3 = Color3.fromRGB(255, 255, 255)
	equip.Parent = card
	newCorner(equip, 8)

	return card
end

local function renderInventory(payload)
	if not inventoryList then return end

	for _, child in ipairs(inventoryList:GetChildren()) do
		if child:IsA("GuiObject") and child ~= itemTemplate and not child:IsA("UIComponent") then
			child:Destroy()
		end
	end

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
			local card
			if itemTemplate then
				card = itemTemplate:Clone()
				card.Visible = true
			else
				card = makeDefaultCard()
			end
			card.Name = "Item_" .. star.Id
			card.BackgroundColor3 = star.Color
			card.Parent = inventoryList

			local isEquipped = (payload.Equipped == star.Id)

			local nameLabel = findDescendant(card, "NameLabel")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = star.Name
			end
			local countLabel = findDescendant(card, "CountLabel")
			if countLabel and countLabel:IsA("TextLabel") then
				countLabel.Text = "x" .. item.Count .. " • 1/" .. star.Chance
			end
			local equipBtn = findDescendant(card, "EquipButton")
			if equipBtn and equipBtn:IsA("GuiButton") then
				equipBtn.Text = isEquipped and "Снять" or "Надеть"
				equipBtn.BackgroundColor3 = isEquipped
					and Color3.fromRGB(220, 200, 60)
					or Color3.fromRGB(40, 40, 80)
				equipBtn.MouseButton1Click:Connect(function()
					if isEquipped then
						equipStar:FireServer(nil)
					else
						equipStar:FireServer(star.Id)
					end
				end)
			end
		end
	end

	-- Если это ScrollingFrame с UIGridLayout/UIListLayout — пересчитаем CanvasSize
	if inventoryList:IsA("ScrollingFrame") then
		local layout = inventoryList:FindFirstChildWhichIsA("UIGridLayout")
			or inventoryList:FindFirstChildWhichIsA("UIListLayout")
		if layout then
			inventoryList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
		end
	end
end

inventoryUpdate.OnClientEvent:Connect(renderInventory)

-------------------------------------------------------------
-- Кнопка-переключатель инвентаря
-------------------------------------------------------------
if inventoryButton and inventoryFrame then
	inventoryButton.MouseButton1Click:Connect(function()
		inventoryFrame.Visible = not inventoryFrame.Visible
	end)
end
