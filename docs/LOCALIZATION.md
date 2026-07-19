# Localization

Sprout Guardians currently supports:

- English (`en`)
- Simplified Chinese (`zh_CN`)

The active locale is detected from the operating system on first launch and then persisted in `user://settings.cfg` under `general/locale`. The in-game language button switches locale immediately without restarting the level.

## Architecture

- `scripts/services/localization_service.gd` owns supported locales, persistence, resource-name helpers, wave previews, and translated text.
- `scripts/localized_main.gd` adapts the gameplay controller without mixing translation tables into the core combat controller.
- `scenes/main.tscn` uses `localized_main.gd` as its scene controller.

Tower, enemy, and wave translation keys are derived from stable data IDs:

```text
tower.<tower_id>.name
tower.<tower_id>.short
tower.<tower_id>.description
enemy.<enemy_id>.name
wave.<wave_id>.name
wave.<wave_id>.hint
```

This keeps save data and gameplay resources language-neutral.

## Adding a language

1. Add the locale code to `SUPPORTED_LOCALES`.
2. Add the new locale value to each entry in `TEXT`.
3. Update `_normalize_locale()` when the locale needs aliases.
4. Add headless tests for core buttons, one tower name, and one wave preview.
5. Check text width at the 640×360 base resolution.

## Translation rules

- Never use translated display text as an ID or save key.
- Keep placeholders (`%d`, `%s`) in the same order across locales.
- Translate tactical meaning rather than word order literally.
- Keep build-bar names short enough for 122-pixel buttons.
- New gameplay text must use `LocalizationService.text()` instead of hard-coded UI strings.
