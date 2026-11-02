# Game headless test harness

Headless verification suites for The Hollow Ouroboros game logic
(`assets/js/game`). Phaser is stubbed (`phaser-stub.js`) and the suites run
under plain node via esbuild bundling — no browser needed.

## Run

```bash
assets/js/game/test/run.sh
```

The runner builds the game bundle once (compile check, output to a temp dir —
`priv/static` is never touched), bundles each suite for node, runs them, and
prints a per-suite + total summary. Non-zero exit if any suite fails.

## Suites

- `phase1-engine.mjs` — upgrade engine: stat/flat/conversion/unlock cards,
  charges deleted, roll buy/use helpers, kanji tiers, TurnManager attack math.
- `phase2-generator.mjs` — card generator: rarity floors + band fallback,
  exclusions, weighting, knowledge effects, pool exhaustion.
- `phase3-scenes.mjs` — UpgradeScene decisions, WinScene routing + battle
  tier roll, LoadoutScene roll triggers (D12).
- `phase4-sites.mjs` — shop cutovers: roll stock/prices, rest-camp one-action
  rule, no ability stock, legacy-save migration.
- `phase5-content.mjs` — full 54-card pool integrity, knowledge semantics,
  run-upgrades model, stamina rebalance, shield profiles, balance sanity.
- `phase6-cleanup.mjs` — remnant sweeps, MAP_VERSION invalidation,
  staminaRegen conversion, chest rewards, cache-version agreement.

## Adding a check

Each suite is a self-contained `.mjs` file using the shared helpers at the
top (`check(name, cond, detail)` counts passes/failures and sets the exit
code). Import game modules with relative paths (`../entities/Player.js`) —
esbuild resolves them at bundle time. Add the file to this directory and the
runner picks it up automatically.
