# Socket Charm JSON Files

These files define every socket charm in the game. They are imported at build time, so the game works offline and does not depend on the Medoru backend.

## Editing

Open the relevant equipment file (e.g., `primary_weapon.json` for sword sockets or `secondary_weapon.json` for shield sockets) and edit the `charms` array. After saving, rebuild the front-end (`mix esbuild medoru`) and deploy.

## Schema

```json
{
  "id": "unique_slug",
  "name": "English name",
  "nameJa": "Japanese name",
  "kanji": "一",
  "slot": 1,
  "color": "#ff6600",
  "description": "Short description.",
  "scaling": {
    "strength": { "fixed": "D" },
    "skill": { "milestones": { "1": "C", "5": "B", "9": "A" } },
    "mana": null
  },
  "abilityFamily": "fire",
  "element": "fire"
}
```

### Fields

- `id` — unique identifier referenced by `ownedSocketCharmIds` and save data.
- `name` / `nameJa` — display names.
- `kanji` — single kanji shown on the charm icon.
- `slot` — socket index this charm can be placed in (currently only `1`).
- `color` — hex color string used for borders and glows.
- `description` — tooltip / card description.
- `scaling` — overrides the equipment's base scaling schedule.
  - `{ fixed: 'D' }` — always use this grade.
  - `{ milestones: { "1": "C", "5": "B" } }` — grade based on equipment upgrade level.
  - `null` — removes this stat from scaling entirely.
- `abilityFamily` — build family used to gate abilities (e.g., `bleed`, `heavy`, `fire`).
- `element` — optional element for elemental charms.
