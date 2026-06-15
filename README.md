# The Plain: Секретов нет

> Мета-хоррор / Рогалик / Android  
> Godot 4.4 · GDScript · Android API 24+

---

## Описание

Процедурно генерируемый мир от третьего лица. Три стадии — рогалик, хоррор, финал.  
Игра знает о твоём устройстве. Игра помнит каждый запуск.

---

## Этапы разработки

| Этап | Содержание | Статус |
|------|-----------|--------|
| **1** | Фундамент: проект, SaveManager, сцены, GitHub Actions | ✅ |
| **2** | Процедурный мир: чанки, террейн, леса, реки | 🔜 |
| **3** | Враги, боевая система, навыки | 🔜 |
| **4** | Здания, деревня, замок, UI/UX | 🔜 |
| **5** | Аудио, мета-хоррор, уведомления (плагин) | 🔜 |
| **6** | Балансировка, полировка, релиз | 🔜 |

---

## Сборка

### Требования

- Godot 4.4 (stable)
- Android SDK (API 34)
- NDK r23c
- Java 17

### Локальная сборка

```bash
# Импорт проекта
godot --headless --import

# Экспорт APK (debug)
godot --headless --export-debug "Android" build/the-plain-debug.apk
```

### Автосборка (GitHub Actions)

Каждый push в `main` → автоматический APK в Releases.

Для подписанного релиза нужны GitHub Secrets:
- `KEYSTORE_BASE64` — keystore закодированный в base64
- `KEYSTORE_PASSWORD` — пароль keystore
- `KEY_ALIAS` — алиас ключа
- `KEY_PASSWORD` — пароль ключа

Генерация keystore:
```bash
keytool -genkey -v -keystore the-plain-release.keystore \
  -alias the-plain -keyalg RSA -keysize 2048 -validity 10000

# Кодируем для GitHub Secret
base64 -w 0 the-plain-release.keystore
```

---

## Структура проекта

```
the-plain/
├── .github/workflows/build.yml   # GitHub Actions
├── project.godot                 # Конфиг Godot
├── export_presets.cfg            # Android export
├── scenes/
│   ├── main/Main.tscn            # Корневая сцена
│   ├── ui/MainMenu.tscn          # Главное меню
│   ├── ui/HUD.tscn               # Интерфейс
│   ├── world/WorldRoguelike.tscn # Этап 1
│   ├── world/WorldHorror.tscn    # Этап 2
│   ├── world/WorldFinal.tscn     # Этап 3
│   └── player/Player.tscn        # Персонаж
├── scripts/
│   ├── Main.gd                   # Менеджер стадий
│   ├── save/SaveManager.gd       # Сохранения (XOR+SHA256)
│   ├── meta/DeviceInfo.gd        # Данные устройства
│   ├── meta/FourthWall.gd        # 4-я стена
│   ├── meta/HorrorTrigger.gd     # Триггеры хоррора
│   ├── meta/NotificationManager.gd # Уведомления Android
│   ├── audio/AudioLayerManager.gd  # 8-слойная музыка
│   ├── player/PlayerMovement.gd  # Движение (свайп-камера)
│   ├── player/PlayerStats.gd     # XP, HP, навыки
│   ├── world/WorldRoguelike.gd   # Мир рогалика
│   ├── world/WorldHorror.gd      # Мир хоррора
│   ├── world/WorldFinal.gd       # Финальная сцена
│   ├── ui/MainMenu.gd            # Логика главного меню
│   ├── ui/HUD.gd                 # Логика HUD
│   ├── ui/GlitchEffect.gd        # Глитч-эффект текста
│   └── encyclopedia/Encyclopedia.gd # Бестиарий
└── assets/
    ├── audio/roguelike/          # 8 слоёв (добавить .ogg)
    ├── audio/horror/             # 6 слоёв (добавить .ogg)
    ├── audio/sfx/                # Эффекты (добавить .ogg)
    ├── sprites/                  # Текстуры врагов и UI
    ├── textures/                 # Террейн, здания, небо
    └── icons/                    # icon_normal.png, icon_horror.png
```

---

## Важные механики

- **Сохранение**: XOR + SHA-256 + монотонная валидация + атомарная запись
- **Смерть**: сбрасывает только данные за забег, стадия остаётся
- **Финал**: полный сброс + выход из игры (необратимо)
- **4-я стена**: глитч-текст с именем героя, модель устройства, время игры
- **Уведомления**: "пора возвращаться" через 1-2 ч после нажатия "Не нажимай"
- **Ночные враги**: +10% скорость 23:00–6:00; батарея <20% → +15% сила

---

## Ассеты (нужно добавить)

| Файл | Описание |
|------|----------|
| `assets/sprites/ui/screamer.png` | Скример (предоставляет автор) |
| `assets/icons/icon_normal.png` | Иконка приложения (обычная) |
| `assets/icons/icon_horror.png` | Иконка приложения (хоррор, Этап 5) |
| `assets/audio/roguelike/layer_01-08.ogg` | 8 слоёв фолк/приключенческой музыки |
| `assets/audio/horror/layer_01-06.ogg` | 6 слоёв хоррор-дрона |
| `assets/audio/sfx/screamer.ogg` | Звук скримера |

---

*GDD: `THE_PLAIN_GDD_1781525317322.md`*
