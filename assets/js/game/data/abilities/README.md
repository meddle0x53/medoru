# Ability JSON Files

These files define every combat ability in the game. They are imported at build time, so the game works offline and does not depend on the Medoru backend.

## Editing

Open the relevant class file (e.g. `warrior.json`) and edit the `abilities` array. After saving, rebuild the front-end (`mix assets.build`) and deploy.

## Schema

```json
{
  "id": "unique_slug",
  "name": "English name",
  "nameJa": "Japanese name",
  "description": "Short description.",
  "type": "attack | defence | parry | item | buff | debuff | heal | attack_defence",
  "element": "physical | fire | water | wind | earth | void | poison | dark | light",
  "equipmentType": "weapon | shield | null",
  "requiredEquipment": "Long Sword | Wooden Shield | null",
  "staminaCost": 3,
  "basePower": 8,
  "scalingStat": "strength | skill | stamina | mana | luck",
  "scalingMultiplier": 1.0,
  "baseBlock": 5,
  "scalingBlockStat": "skill",
  "scalingBlockMultiplier": 0.4,
  "baseParryChance": 0.15,
  "kanji": "力",
  "rarity": "normal | rare | epic | legendary",
  "moveHint": { "en": "...", "ja": "..." },
  "config": {},
  "lifecycle": {
    "onUse": ["dealDamage"],
    "onHit": [],
    "onTurnEnd": []
  },
  "effects": [
    {
      "effectId": "burn",
      "target": "enemy | self",
      "chance": { "base": 0.10, "step": 0.05, "cap": 0.35 },
      "duration": { "min": 3, "max": 5 },
      "condition": "always | burn_applied | hit",
      "payload": { "element": "fire" }
    }
  ]
}
```

### `lifecycle`

Lists behavior hooks the engine will call. Hook names are resolved by the version-controlled behavior registry (not by JSON), so admin-edited files cannot run arbitrary code.

Common hooks:

- `dealDamage` — attack damage using `basePower`, `scalingStat`, etc.
- `gainBlock` — add block using `baseBlock` / `scalingBlockStat`.
- `setupParry` — enable a parry for the next enemy attack.
- `useItem` — open the item selection UI.
- `setReadiness` — set the readiness meter from `config.setReadiness`.
- `applyTaunt` — force enemy targeting and lower enemy defense.
- `gainDodge` — dodge the next enemy attack.
- `applyBuff` — apply a generic buff from `config.buffType`.

### `effects`

References entries in `assets/js/game/systems/EffectRegistry.js` by `effectId`. The engine applies these after resolving the ability’s lifecycle hooks.

### `element` and infusions

- Normal abilities use `"physical"`.
- Elemental abilities use `"fire"`, `"water"`, `"wind"`, `"earth"`, or `"void"`.
- A buff can apply the `element_infuse` effect with a `payload.element`. While that buff is active, the next ability used is treated as that element (unless the ability itself is `physical` and the infusion overrides it).

### `config`

Free-form extra parameters for the behavior hooks. Examples:

- `{ "ignoreDefense": true }` for guard-breaking attacks.
- `{ "buffType": "sword_damage_bonus" }` for generic buffs.
- `{ "setReadiness": 1.0 }` for Focus.

## Adding a new class

1. Create `<class>.json` in this folder.
2. Import it in `index.js` and spread it into `ALL_ABILITIES`.
3. Add class-specific starter selection logic in `Player` / loadout code.
