# Plan: Phaser 4 High-DPI / Fullscreen Sharpness Refactor

**Status:** Postponed  
**Goal:** Render the game at the display’s physical pixel resolution so sprites, kanji, and text stay crisp in fullscreen, instead of upscaling a 960×540 buffer.

## Why this is needed

- The game is authored at a fixed 960×540 logical resolution.
- Phaser 4 ignores the `resolution` config option, so the canvas drawing buffer stays at 960×540.
- In fullscreen the browser scales that low-res buffer up, causing blur — especially on text/kanji and on sprites displayed small (e.g., Danzaburō-danuki at layout scale 0.18).
- Manually resizing the canvas after creation breaks Phaser 4’s viewport.

## High-level approach

Create the Phaser game at the target **physical pixel size** and scale all content back down so the 960×540 design remains the same apparent size.

```
PX = target_physical_width / 960
GAME_WIDTH  = 960 * PX
GAME_HEIGHT = 540 * PX
```

`PX` should be computed once at startup, capped (e.g., 2–4) for performance.

## Two possible implementation strategies

### Strategy 1: Root container per scene (recommended)

- Create a `worldContainer` in every scene, scaled by `1 / PX`.
- Add all game objects (sprites, text, graphics, containers, UI) to `worldContainer` instead of directly to the scene.
- Input/pointer transforms continue to work automatically because Phaser applies container transforms to input.
- Requires less coordinate math but needs every scene’s `create()` method refactored.

### Strategy 2: Multiply every coordinate

- Keep game size at physical pixels and leave camera zoom at 1.
- Multiply every `x`, `y`, `scale`, `fontSize`, `width`, `height` value by `PX`.
- Also scale input/pointer handling where needed.
- More invasive and error-prone; not recommended.

## Files likely to change

- `assets/js/game.js` — compute `PX`, create game at `960*PX` × `540*PX`.
- `assets/js/hooks/game_hook.js` — compute `PX` before starting the game and pass it in.
- `assets/js/game/config.js` — expose `GAME_CONFIG` and possibly a `PX` helper.
- Base scene or new scene plugin — create and manage `worldContainer`.
- Every scene under `assets/js/game/scenes/`:
  - `TitleScene.js`
  - `HeroSelectScene.js`
  - `HomeShopScene.js`
  - `OuroEssenceShopScene.js`
  - `MapScene.js`
  - `LoadoutScene.js`
  - `BattleScene.js`
  - `MemoryScene.js`
  - `ShopScene.js`
  - `RestScene.js`
  - `SocketScene.js`
  - `WinScene.js`
  - `RunVictoryScene.js`
  - `CascadeScene.js`
  - `ChestScene.js`
  - plus any utility/HUD classes that add display objects directly to scenes.

## Steps if/when we proceed

1. Add a `PX` helper to `config.js` that computes the multiplier from `devicePixelRatio` and fullscreen target size, with a cap.
2. Update `game.js` and `game_hook.js` to create the game at physical size.
3. Create a base scene mixin/plugin that adds a `worldContainer` scaled by `1 / PX`.
4. Migrate one low-risk scene first (e.g., `TitleScene`) to the root-container pattern and verify sharpness + input.
5. Migrate remaining scenes one by one.
6. Test fullscreen, windowed, input, battle, shop, map, and text readability.
7. Cache-bust the bundle and service worker.

## Risks / open questions

- **Performance:** fill rate grows by `PX²`. Cap `PX` to avoid killing low-end GPUs.
- **Fullscreen changes:** If the user moves the window between monitors with different DPRs, the game would need to be recreated. For now, compute `PX` once at startup based on the current/max expected display.
- **Input:** Strategy 1 should keep input working, but custom pointer math (e.g., drag, custom buttons) needs testing.
- **Text/Fonts:** Phaser Text objects may need font sizes recalculated or rendered at larger sizes.
- **Cameras/Effects:** Camera shake, fade, flash, and particle effects must be checked inside the scaled container.

## Quick alternative (if refactor is too big)

Increase the Danzaburō-danuki layout scale from `0.18` to `0.28`–`0.30` in `assets/js/game/data/enemies/danzaburo_danuki.json` and bump nameplate font sizes. This uses more of the existing 960×540 pixels without engine changes.
