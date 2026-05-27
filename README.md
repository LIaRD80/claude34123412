# Stars RNG ⭐

Игра в жанре RNG для Roblox, вдохновлённая Pet RNG / Sol's RNG.
Жмёшь **ROLL** → летит лента с карточками звёзд → она тормозит и
останавливается на той звезде, которую тебе выпало (от обычной жёлтой
до секретной «Вселенной» с шансом 1 к миллиону).

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

Шансы и цвета — в `src/ReplicatedStorage/StarsConfig.lua`.

## Структура файлов

```
default.project.json              ← Rojo-конфиг
src/
  ReplicatedStorage/
    StarsConfig.lua              ← список звёзд, шансы, цвета
  ServerScriptService/
    StarsServer.server.lua       ← обработка Roll / Equip, инвентарь
    AuraServer.server.lua        ← аура (свет + частицы) на персонаже
  StarterPlayerScripts/
    StarsClient.client.lua       ← логика: кнопка → ролл → лента → результат
```

## ❗ UI ты делаешь сам в StarterGui

Скрипт ищет твои элементы **по имени**. Достаточно сделать вот это:

```
StarterGui/
  StarsGui                         (ScreenGui) — обязательно
    RollButton                     (TextButton)  ← обязательно
      CooldownBar                  (Frame)       — опц., Size.X.Scale тянется 0→1
    RollsLabel                     (TextLabel)   — опц., текст "Роллы: 12"
    ResultLabel                    (TextLabel)   — опц., текст "Сверхновая • Mythic • 1/10000"
    InventoryButton                (TextButton)  — опц., открывает InventoryFrame
    InventoryFrame                 (Frame)       — опц., изначально Visible=false
      InventoryList                (ScrollingFrame, желательно с UIGridLayout)
        ItemTemplate               (Frame)       — опц., шаблон карточки. Внутри ищутся:
          NameLabel                (TextLabel)
          CountLabel               (TextLabel)
          EquipButton              (TextButton)
```

- **Минимум, что нужно** — `StarsGui` и в нём `RollButton`. Остальное опционально:
  если чего-то нет, скрипт просто пропустит его.
- Поиск по имени **рекурсивный**, так что элементы можно класть в любые контейнеры/декоры.
- Анимация ленты прокрутки **создаётся скриптом сама** поверх твоего GUI, рисовать её
  в StarterGui не надо.

## Анимация ленты

При ролле скрипт:
1. Затемняет экран
2. Создаёт длинную горизонтальную полосу из ~60 карточек звёзд (взвешенно: реже — Mythic/Secret)
3. На позиции №54 ставит ту звезду, которую вернул сервер
4. Пускает Tween с `Quint Out` на ~4 секунды — лента летит и плавно тормозит
5. Выигравшая карточка пульсирует и подсвечивается
6. Через 1.5 сек оверлей плавно закрывается, обновляется `ResultLabel` и `RollsLabel`

## Как открыть в Roblox Studio

### Через Rojo (рекомендуется)

1. Установи Rojo: <https://github.com/rojo-rbx/rojo/releases/latest>
2. Склонируй репо: `git clone <url>` или через GitHub Desktop
3. В папке репо запусти:
   ```bash
   rojo serve
   ```
4. В Studio: плагин Rojo → **Connect** → файлы появятся в нужных местах.
5. В **StarterGui** собери свой `StarsGui` (см. структуру выше) и жми **Play** ▶️

### Вручную (без Rojo)

1. В Roblox Studio в **ReplicatedStorage** → ModuleScript `StarsConfig` ← вставь
   `src/ReplicatedStorage/StarsConfig.lua`
2. В **ServerScriptService** → два Script:
   - `StarsServer` ← `StarsServer.server.lua`
   - `AuraServer` ← `AuraServer.server.lua`
3. В **StarterPlayer → StarterPlayerScripts** → LocalScript `StarsClient`
   ← `StarsClient.client.lua`
4. В **StarterGui** собери `StarsGui` с `RollButton` (и опциональными элементами).
5. Save → Play.

## Дальше можно добавить

- 💾 Сохранение инвентаря через `DataStoreService`
- 🪐 Биомы (день/ночь/космос) с бонусами к шансам
- 🛒 Магазин Gamepass: Lucky 2x, Auto-Roll, Fast Roll
- 📜 Codex/индекс «собрал X из 8»
- 🔊 Звуки тиканья ленты и финального лендинга
- 🏆 Бейджи за получение редких звёзд

## Аудитория

Дизайн рассчитан на 9+: одна большая кнопка, понятные цвета редкости,
крупный шрифт, эмодзи, мультяшная палитра, понятная CS:GO-style лента.
