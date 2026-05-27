# Stars RNG ⭐

Игра в жанре RNG для Roblox, вдохновлённая Pet RNG / Sol's RNG.
Игрок жмёт кнопку **ROLL** и получает случайную звезду — от обычной жёлтой
до секретной «Вселенной» с шансом 1 к миллиону.

## Звёзды

| Имя | Редкость | Шанс |
|---|---|---|
| Жёлтая звезда | Common | 1/2 |
| Красная звезда | Uncommon | 1/8 |
| Синяя звезда | Rare | 1/40 |
| Зелёная звезда | Epic | 1/200 |
| Фиолетовая звезда | Legendary | 1/1 000 |
| Сверхновая | Mythic | 1/10 000 |
| Чёрная дыра | Godly | 1/100 000 |
| Вселенная | Secret | 1/1 000 000 |

Редкости легко балансируются в `src/ReplicatedStorage/StarsConfig.lua`.

## Фичи MVP

- Кнопка **ROLL** с кулдауном 3 сек
- Серверный анти-спам (нельзя обойти клиентом)
- Инвентарь звёзд с подсчётом
- Возможность «надеть» звезду — вокруг персонажа появляется аура
  (PointLight + ParticleEmitter) её цвета
- Полноэкранный «reveal» для редкостей **Legendary** и выше
- Весь UI собирается из Lua-скрипта (без `.rbxmx`)

## Структура

```
default.project.json              ← Rojo-конфиг
src/
  ReplicatedStorage/
    StarsConfig.lua              ← список звёзд, шансы, цвета
  ServerScriptService/
    StarsServer.server.lua       ← обработка Roll / Equip, инвентарь
    AuraServer.server.lua        ← аура (свет + частицы) на персонаже
  StarterPlayerScripts/
    StarsClient.client.lua       ← UI, кнопка Roll, инвентарь, reveal
```

## Как открыть в Roblox Studio

### Вариант 1: через Rojo (рекомендуется)

1. Установите Rojo: <https://rojo.space/docs/v7/getting-started/installation/>
2. В корне репо запустите:
   ```bash
   rojo serve
   ```
3. В Studio установите плагин Rojo и подключитесь к серверу (порт 34872).

### Вариант 2: вручную скопировать скрипты

1. В Roblox Studio создайте пустое место.
2. В **ReplicatedStorage** создайте `ModuleScript` с именем `StarsConfig`
   и вставьте содержимое `src/ReplicatedStorage/StarsConfig.lua`.
3. В **ServerScriptService** создайте два `Script`:
   - `StarsServer` ← `src/ServerScriptService/StarsServer.server.lua`
   - `AuraServer` ← `src/ServerScriptService/AuraServer.server.lua`
4. В **StarterPlayer → StarterPlayerScripts** создайте `LocalScript`
   `StarsClient` ← `src/StarterPlayerScripts/StarsClient.client.lua`
5. Нажмите **Play** — кнопка ROLL появится снизу по центру.

## Дальше можно добавить

- 💾 Сохранение инвентаря в `DataStoreService` (сейчас только сессия)
- 🪐 Биомы: ночь даёт +удачу синим звёздам, и т.д.
- 🛒 Магазин Gamepass: **Lucky 2x**, **Auto-Roll**, **Fast Roll**
- 📜 Индекс / Codex с прогрессом «собрал X из 8»
- 🤝 Trading между игроками
- 🔊 Звуки: ролл / редкость / секрет
- 🏆 Бейджи за получение редких звёзд

## Возрастная аудитория

Дизайн рассчитан на 9+: одна большая кнопка, понятные цвета редкости,
крупный шрифт `FredokaOne`, эмодзи и яркая мультяшная палитра.
