-- StarsConfig.lua
-- Список всех звёзд в игре. Чем больше Chance — тем реже звезда (1 из Chance).
-- Цвета используются для ауры вокруг игрока и для UI.

local StarsConfig = {}

StarsConfig.RollCooldown = 3 -- секунды между роллами

StarsConfig.Stars = {
	{
		Id = "yellow",
		Name = "Жёлтая звезда",
		Rarity = "Common",
		Chance = 2,
		Color = Color3.fromRGB(255, 230, 80),
		GlowColor = Color3.fromRGB(255, 255, 180),
	},
	{
		Id = "red",
		Name = "Красная звезда",
		Rarity = "Uncommon",
		Chance = 8,
		Color = Color3.fromRGB(255, 80, 80),
		GlowColor = Color3.fromRGB(255, 140, 140),
	},
	{
		Id = "blue",
		Name = "Синяя звезда",
		Rarity = "Rare",
		Chance = 40,
		Color = Color3.fromRGB(80, 150, 255),
		GlowColor = Color3.fromRGB(140, 200, 255),
	},
	{
		Id = "green",
		Name = "Зелёная звезда",
		Rarity = "Epic",
		Chance = 200,
		Color = Color3.fromRGB(80, 255, 120),
		GlowColor = Color3.fromRGB(160, 255, 180),
	},
	{
		Id = "purple",
		Name = "Фиолетовая звезда",
		Rarity = "Legendary",
		Chance = 1000,
		Color = Color3.fromRGB(180, 80, 255),
		GlowColor = Color3.fromRGB(220, 140, 255),
	},
	{
		Id = "supernova",
		Name = "Сверхновая",
		Rarity = "Mythic",
		Chance = 10000,
		Color = Color3.fromRGB(255, 120, 40),
		GlowColor = Color3.fromRGB(255, 220, 150),
	},
	{
		Id = "blackhole",
		Name = "Чёрная дыра",
		Rarity = "Godly",
		Chance = 100000,
		Color = Color3.fromRGB(40, 0, 80),
		GlowColor = Color3.fromRGB(180, 80, 255),
	},
	{
		Id = "universe",
		Name = "Вселенная",
		Rarity = "Secret",
		Chance = 1000000,
		Color = Color3.fromRGB(20, 20, 40),
		GlowColor = Color3.fromRGB(255, 255, 255),
	},
}

StarsConfig.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(120, 220, 120),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 200, 50),
	Mythic = Color3.fromRGB(255, 100, 50),
	Godly = Color3.fromRGB(255, 50, 100),
	Secret = Color3.fromRGB(255, 255, 255),
}

function StarsConfig.GetById(id)
	for _, star in ipairs(StarsConfig.Stars) do
		if star.Id == id then
			return star
		end
	end
	return nil
end

return StarsConfig
