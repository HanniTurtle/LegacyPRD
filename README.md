# LegacyPRD - Personal Resource Display

**Bring back the Legacy Personal Resource Display you know and love.**

With the changes in Patch 12.0.0, Blizzard overhauled the Personal Resource Display — removing its character-anchored behavior, stripping buff tracking, and replacing it with a static HUD element. LegacyPRD restores a familiar, customizable personal resource bar that puts your health, power, class resources, and cast bar right where they belong.

---

## Features

### Health & Power Bar
- Clean, minimal health and power bar display
- Health bar color options: **Class Color**, **Green**, or a fully **Custom Color**
- Power bar color options: **Default** (per resource type) or **Custom Color**
- Show or hide health bar and power bar independently
- Thin black separator between health and power bar for a unified look
- Subtle 1px black border wrapping the bars into one cohesive unit
- Automatic combat fade: full opacity in combat, reduced opacity out of combat

### Class Resources
- Displays class-specific secondary resources below (or above) the bar:
  - **Warlock** — Soul Shards
  - **Rogue** — Combo Points
  - **Druid** — Combo Points (Cat Form)
  - **Paladin** — Holy Power
  - **Monk** — Chi
  - **Death Knight** — Runes (spec-colored: Blood, Frost, Unholy)
  - **Mage** — Arcane Charges (Arcane spec)
  - **Evoker** — Essence
- Three display styles:
  - **Blizzard** — Original Blizzard atlas icons (diamond shards, glowing combo points, etc.)
  - **Bar** — Segmented horizontal bar that matches the health/power bar style
  - **Squares** — Simple colored square indicators
- Depleted resources stay visible in a dimmed state — never fully hidden
- Resource position: **Top** or **Bottom**
- Custom color options for Bar and Squares styles: **Class Default**, **Class Color**, or **Custom Color**

### Cast Bar
- Optional integrated cast bar (off by default)
- Displays spell name and cast time
- Gold color for normal casts, red for non-interruptible spells
- Shows cast status (Interrupted, Failed) with auto-hide
- Position: **Top** or **Bottom** of the display
- Adjustable height

### Full Customization
All settings are accessible via the Blizzard AddOns options panel or the `/lprd` slash command:

- **Lock/Unlock** — Drag the frame freely when unlocked with a visual move handle
- **Scale** — 1% to 200% (default 100%)
- **Width** — 1% to 200% (default 100%)
- **Height** — 1% to 200% (default 100%)
- **Resource Icon Size** — 50% to 200%
- **Resource Icon Spacing** — 0px to 50px
- **Cast Bar Height** — 50% to 200%
- **Reset to Default** — One-click reset for all settings

---

## Slash Commands

| Command | Action |
|---------|--------|
| `/lprd` | Open the LegacyPRD settings panel |

---

## Installation

1. Download and extract into your `World of Warcraft/_retail_/Interface/AddOns/` folder
2. Restart WoW or type `/reload`
3. Open **Options → AddOns → LegacyPRD** to configure

---

## FAQ

**Q: Does this replace the Blizzard Personal Resource Display?**
A: LegacyPRD automatically hides the default Blizzard personal nameplate to avoid conflicts. You get a cleaner, more customizable replacement.

**Q: Does this work with other nameplate addons?**
A: Yes. LegacyPRD is a standalone frame and does not modify enemy or friendly nameplates. It works alongside Plater, Platynator, KUI, ThreatPlates, and others.

**Q: My class isn't listed under Class Resources. Will it still work?**
A: The health and power bar work for every class. Class resource indicators are only shown for classes with a secondary resource (Soul Shards, Combo Points, Holy Power, Chi, Runes, Arcane Charges, Essence). Classes without one (e.g. Warrior, Hunter) simply won't show the resource row.

**Q: Is this addon compatible with Patch 12.0.0 API restrictions?**
A: Yes. LegacyPRD only uses visual and display APIs. It does not rely on any restricted combat logic or secret values.

---

## Feature Requests & Bug Reports

Have an idea for a new feature or found a bug? **I'd love to hear from you!**

- **CurseForge:** Leave a comment on the project page
- **GitHub Issues:** [Submit an issue on GitHub](https://github.com/HanniTurtle/LegacyPRD/) 

Community feedback drives this addon — your suggestions help make LegacyPRD better for everyone. Whether it's a new customization option, support for additional class mechanics, or a visual tweak, don't hesitate to reach out!

---

## Changelog

### v1.0.1

**Bug Fix:**
- Fixed a bug where the addon duplicated the default Blizzard buff bar near the minimap
- Removed all built-in buff/aura tracking to prevent conflicts with the Blizzard UI
- The addon now focuses purely on Health, Power, Class Resources, and Cast Bar as intended

### v1.0.0
- Initial release
- Health and power bar with class color, green, and custom color options
- Class resource display with Blizzard, Bar, and Squares styles
- Optional cast bar with top/bottom positioning
- Full settings panel with scale, width, height, spacing, and color customization
- Show/hide toggles for health bar, power bar, class resources, and cast bar
- Movable frame with lock/unlock
- Reset to default button
