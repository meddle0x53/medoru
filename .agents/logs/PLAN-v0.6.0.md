# PLAN v0.6.0 — Classroom Themes

## Overview
Teachers can set a custom site theme for their classroom. All students viewing that classroom see the chosen theme (buttons, menus, backgrounds, cards, etc.). Each theme has both a light and dark variant that respects the user's system/settings preference.

## Main Feature: Per-Classroom DaisyUI Themes

### Backend
- **Migration**: Add `theme` string field to `classrooms` table (default `nil`, falls back to site default)
- **Schema**: `Classroom` schema gets `theme` field with validation against allowed DaisyUI theme names
- **Context**: `Classrooms.update_classroom_theme/2` or extend `update_classroom/2`
- **Allowed themes**: All DaisyUI built-in themes (e.g. `light`, `dark`, `cupcake`, `bumblebee`, `emerald`, `corporate`, `synthwave`, `retro`, `cyberpunk`, `valentine`, `halloween`, `garden`, `forest`, `aqua`, `lofi`, `pastel`, `fantasy`, `wireframe`, `black`, `luxury`, `dracula`, `cmyk`, `autumn`, `business`, `acid`, `lemonade`, `night`, `coffee`, `winter`, `dim`, `nord`, `sunset`)

### Frontend
- **Root layout**: Apply `data-theme` attribute on `<html>` based on current classroom's theme
  - If no classroom theme is set → use user's/system preference (current behavior)
  - If classroom theme is set → use classroom theme, still respecting light/dark preference
- **Teacher settings UI**: Theme picker in classroom settings
  - Visual preview cards showing each theme's color palette
  - Light/dark toggle in preview
  - "Reset to default" option

### Scope
- Theme applies when viewing:
  - Classroom show page
  - Classroom lessons
  - Classroom chat
  - Classroom rankings
- Theme does NOT apply when viewing global pages (dashboard, user directory, games, public pages)

## Other Potential Features for v0.6.0
TBD — to be decided during iteration planning.

## Technical Notes
- DaisyUI themes are already compiled into the CSS bundle
- Switching themes is a runtime CSS change via `data-theme` — no extra CSS download needed
- Need to audit hardcoded Tailwind colors (e.g. `bg-slate-800`, `text-gray-400`) and replace with semantic DaisyUI classes where theming should apply
