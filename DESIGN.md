# Cairn — design

Recorded from the built app (2026-09-27). Ground truth is the code in `Sources/Cairn/UI/Theme.swift`; this file describes it.

## World

Sand-white paper, sumi ink, one chalk-bag red. Taken from the brief's references: the ink-sketch climbers (black line, a single red spot colour), the ink-wash mountain with small figures on a traced route, and the frosted glass data cards with blurred light behind them.

- **The route reads upward. The future is always above you.** The mountain page draws the 14-week block as switchbacks up a snowfield; camps are weeks, labelled in a left gutter like a climbing topo, leader lines elbowing to each camp.
- **Glass only where light means something.** One frosted card per screen at most — the week card on Today — lit from behind by the current phase's colour.
- **Red means you.** The climber marker, today, unlocked quests, "step up". Nothing decorative is red.

## Colour (Ink)

| Token | Hex | Use |
|---|---|---|
| paper | `#F4EFE6` | window ground (sand white) |
| sheet | `#FCFAF6` | cards |
| sand / sandDeep | `#ECE4D5` / `#E2D8C5` | inset fields, chips, selected sidebar row |
| line / lineStrong | `#E4DBCC` / `#CDBFA8` | card borders, hand-drawn rules |
| ink | `#1F1C19` | text, primary buttons, done states |
| ink2 | `#5A534A` | secondary text (7:1 on sheet) |
| ink3 | `#857C6E` | large or non-essential only |
| red | `#D3392B` | you / today / unlocked |
| wash | `#2B3540` | sumi blue-black for the painting |

Phase light (glass card, route log dots): Foundation pale sky, Build sun→blush, Push blush→sun, Deload/Return sage, Holiday lilac, Test gold.

Light appearance is forced: the brief is white.

## Type (Face)

SF Pro throughout. Page titles and numerals use the **expanded** width (`.width(.expanded)`), light weight at display sizes — the guidebook/instrument voice. Body is regular SF at 13.5. No eyebrow labels above headings; numbers lead their own labels.

## Components

- `sheetCard` — white card, 16 pt continuous corners, 1 px line border, two soft offset shadows.
- `Rule` — a hand-drawn pen line (seeded wobble) instead of dividers.
- `PhaseGlass` — the one glass surface.
- `InkButtonStyle` — capsule; filled ink for the primary action, outlined for the rest.
- `ChipStyle` — sand capsules; ink when on.
- `SetBubble` — one capsule per set: click to tick, hover for −/+. A red ring when a ticked set reaches the top of the range.
- `StepperField`, `KgField` — sand capsules with tabular numerals.

## Motion

One authored moment: opening the mountain, the route draws and the climber moves from where you last saw it to where you are now (spring, 2.2 s). Numbers use `.numericText()` transitions. The marker pulses. Everything respects Reduce Motion; the glass respects Reduce Transparency.

## The painting

`MountainPainting` is a deterministic Canvas: far-range wash, paper mass, a wash fading to snow, four blurred rock ribs, ~1,400 brush streaks falling from a midpoint-displaced ridge (denser high up, white gullies left by a slow wave, lee faces darker), then a pressure-varying ridge pen line and base mist.
