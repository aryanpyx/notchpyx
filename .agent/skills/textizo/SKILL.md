---
name: textizo
description: Complete toolkit for Textizo (by Clipizo/Clipyx) procedural animated text in DaVinci Resolve's Fusion page. Generates ready-to-use .setting preset files, validates timing formulas, manages 14 animation follower rows, and configures 8-layer shading elements according to the official Textizo AI Guide.
---

# Textizo AI Guide & Skill

This skill enables AI agents to author, validate, and install **Textizo** animated text presets for **DaVinci Resolve's Fusion page** (from `clipizo.com` and `clipyx.com`).

---

## 1. Quick Start & Preset Workflow

1. **Preset Format:** Textizo presets are Fusion settings files (`.setting`) representing a single `Fuse.Textizo` node.
2. **Preset Naming Convention:**
   - Every preset receives a short name: `Textizo-` followed by a two-digit number and a capital letter (e.g. `Textizo-01A`, `Textizo-02A`).
   - New looks take the next number (`Textizo-01A`, `Textizo-02A`).
   - Variations of a look keep the number and advance the letter (`Textizo-01B`, `Textizo-01C`).
3. **Resolve Installation Path:**
   - **Windows:** `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Settings`
   - **macOS:** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Settings`
   - **Linux:** `~/.local/share/DaVinciResolve/Fusion/Settings`
4. **Loading in Resolve:**
   - **New Node:** Copy the `lua` code block, click an empty spot in the Fusion Nodes area, and press **Ctrl+V** (**Cmd+V** on Mac). Connect to `MediaOut1` or foreground of a `Merge` node.
   - **Existing Node:** Right-click the Textizo node -> **Settings > Load...** -> select the `.setting` file.

---

## 2. Response Protocol (Strict 3-Part Reply)

When asked to generate a Textizo preset, the agent **MUST** structure its response in three distinct parts:
1. **Description:** 1-2 sentences describing the animation, mood, and timing. The first line must announce the short name (e.g., `Textizo-01A`).
2. **Code Block:** Exactly **one** code block marked `lua` containing the complete `.setting` node text. No inline comments or extra nodes.
3. **Usage Steps:** 3-4 concise lines explaining how to paste, connect, and customize text in the Inspector.

---

## 3. Strict Preset Authoring Checklist

Before delivering any preset, verify every item:

- [ ] **One Node Structure:** Single node `Textizo1 = Fuse.Textizo { Inputs = { ... } }` inside `{ Tools = ordered() { ... } }`.
- [ ] **Mandatory Inputs:**
  - `StateVersion = Input { Value = 11, }`
  - `InEnable = Input { Value = 1, }`
  - `UseFrameFormatSettings = Input { Value = 1, }`
  - `Width = Input { Value = 1920, }`, `Height = Input { Value = 1080, }` (prevents 320x240 bug)
  - `StyledText = Input { Value = "...", }`
  - `TextEdited = Input { Value = 1, }`
  - All text controls written: `Font`, `Style`, `Size`, `Center`, `Tracking`, `LineSpacing`, `Alignment`, `Rotation`, `Red = 1`, `Green = 1`, `Blue = 1`, `Alpha = 1`.
- [ ] **All 14 Animation Rows Explicitly Written:**
  - 7 Entrance (`In`) rows: `Inopacity`, `Inblur`, `Incenter`, `Insize`, `Intracking`, `Inrotation`, `Inexplosion`.
  - 7 Exit (`Out`) rows: `Outopacity`, `Outblur`, `Outcenter`, `Outsize`, `Outtracking`, `Outrotation`, `Outexplosion`.
  - Every row has `...Enable = Input { Value = 0 or 1, }`.
  - Rows with `Enable = 1` have all required follower, frame, stagger, and curve IDs.
  - `...CurvePreset` and `...CurvePresetID` match (e.g., `FuID { "out_cubic" }` and `"out_cubic"`).
  - **Out rows NEVER include `...StartValue`**.
- [ ] **Timing Verification:**
  - $EndFrame = StartFrame + S + D \times (N - 1)$
  - $Stagger\% = 100 \times D / S$ (0 when $N = 1$)
  - Entrance finishes before exit starts. Exit ends before the clip's last frame (default: 5s at 24 fps = frame 119).
- [ ] **Shading Proxy Rule (Critical):**
  - `ShadingActiveElement = Input { Value = FuID { "element_1" }, }`
  - Element 1 is written **TWICE**: once as `ShadingProxy...` and once as `ShadingElement1...` with **identical** values across all 24 fields.
  - Elements 2 through 8 have `Enable = 0`, or their full block written.
- [ ] **Explosion Rule:** In any Explosion row, `RotationX`, `RotationY`, and `Rotation` are `0`. Use the Rotation row instead.
- [ ] **Safe Fonts:** Arial, Arial Black, Verdana, Tahoma, Trebuchet MS, Georgia, Times New Roman, Impact, Courier New.

---

## 4. Animation Rows Reference

| Row ID | Inspector Name | Value Range / Units | Typical Entrance | Notes |
|---|---|---|---|---|
| `opacity` | Opacity | 0 to 1 | 0 to 1 | Clean fade |
| `blur` | Blur | 0 to 0.27 (frame widths) | 0.12 to 0 | Extra softness; 0.1 is ~11px at 1080p |
| `center` | Position | `{ x, y }` normalized offsets | `{ 0, -0.06 }` to `{ 0, 0 }` | +y is up; x and y in frame dimensions |
| `size` | Size | 0 to 4+ scale factor | 1.1 to 1 (settle), 0 to 1 (pop) | Scale around piece's own center |
| `tracking` | Tracking | frame width offset | 0.05 to 0 | Spreads letters/words; gathers in |
| `rotation` | Rotation | degrees | -120 to 0 | Spins around piece center |
| `explosion` | Explosion | 0 to 1.5 frame widths | 0.4 to 0 | Flies along random directions |

---

## 5. Eases Reference

| ID | Recommended Use |
|---|---|
| `out_cubic`, `out_quart`, `out_expo` | Entrances: fast start, soft landing |
| `out_back` | Gentle overshoot / snap |
| `out_elastic` | Springy pop / wobble |
| `out_bounce` | Drop and bounce |
| `in_quad`, `in_cubic`, `in_back` | Exits: clean acceleration away |
| `in_out_sine` | Smooth fades |

---

## 6. Shading Elements & Recipes

- **Element 1:** Text fill (always enabled).
- **Appearance:** `0` Normal (fill), `1` Outline, `2` Border Fill (box), `3` Border Stroke (box outline).
- **Sticker Look:**
  - Element 1: Bright fill.
  - Element 2: Outline, black, thickness `0.00375 * Size`.
  - Element 3: Normal, black, offset `{ 0.0025 * Size, -0.005 * Size }`, opacity `0.85`.
- **Caption Pill:**
  - Element 2: Border Fill, `BorderLevel = 2` (lines), `BorderExtendX = 0.6 * em`, `BorderExtendY = 0.28 * em`, `BorderRound = 1 * em` (where $em = 0.064 \times Size$).

---

## 7. Clipyx Suite Integration

When working with Clipyx local tools (`c:\Users\aryan\Downloads\Clipyx`):
- Run `python clipyx.py preset list` to view installed presets.
- Run `python clipyx.py preset check "<file.setting>"` to validate syntax and timing.
- Run `python clipyx.py preset install resolve "<file.setting>"` to install directly to DaVinci Resolve.
