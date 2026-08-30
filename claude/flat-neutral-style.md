# Flat Neutral Style Guide

A dense, flat, bordered UI aesthetic: neutral grayscale surfaces, hard corners,
borders instead of shadows, and color used only as signal. Tailwind classes
below; the same values apply to any CSS.

Apply this when asked for "the flat style", "the job-alerts style", "squared /
neutral look", or when extending a project already built this way.

## Core Rules

1. **No rounded corners.** Everything is square. Either use `rounded-none` on
   every element, or add one global override:
   ```css
   *:not(svg):not(path) { border-radius: 0 !important; }
   ```
   The global override is preferred in a retrofit: one line, nothing to miss,
   and it squares third-party widgets (slider thumbs, date pickers) too.
2. **Borders, not shadows.** Separate surfaces with `border` + a neutral border
   color. No `shadow-*`. Popovers, modals, dropdowns, cards: bordered panels.
3. **Grayscale by default.** Backgrounds, text, borders, and controls are all
   `neutral-*`. A color appears only when it carries meaning (see Accents).
4. **Dense.** Small text (`text-xs` / `text-sm`), tight padding (`px-2 py-1` to
   `px-3 py-1.5`), `gap-1` to `gap-3`.
5. **Uppercase micro-headings.** Section titles are
   `text-xs font-semibold uppercase tracking-widest text-neutral-500`.
6. **Monospace for numbers.** Counts, percentages, IDs, timestamps:
   `font-mono text-xs`.
7. **Interactive elements show `cursor: pointer`** when enabled; disabled
   controls are visibly muted (`disabled:opacity-40`) and not clickable.

## Palette

### Dark (default / dark-only apps)

| Role | Token | Hex |
|------|-------|-----|
| Page background | `bg-neutral-950` | `#0a0a0a` |
| Raised surface (card, modal, popover, input) | `bg-neutral-900` | `#171717` |
| Hover fill | `bg-neutral-800` | `#262626` |
| Primary text | `text-neutral-100` | `#f5f5f5` |
| Secondary text | `text-neutral-400` | `#a3a3a3` |
| Muted / label text | `text-neutral-500` | `#737373` |
| Panel border | `border-neutral-800` | `#262626` |
| Input / control border | `border-neutral-700` | `#404040` |
| Hover border | `border-neutral-600` | `#525252` |
| Focus ring | `ring-1 ring-neutral-500` | `#737373` |

### Light (dual-theme apps)

Mirror the scale: `bg-neutral-50` page, `bg-white` surface,
`hover:bg-neutral-100`, `text-neutral-900` primary, `text-neutral-500` muted,
`border-neutral-200` panels, `border-neutral-300` controls. Drive it with a
`.dark` class on `<html>` (seeded by an inline boot script to avoid flash), not
media queries.

## Components

### Primary button
```
bg-blue-600 text-white hover:bg-blue-500 px-4 py-2 text-sm font-medium disabled:opacity-40
```
For a strictly monochrome variant, invert instead of coloring:
`bg-neutral-100 text-neutral-900 hover:bg-neutral-200`.

### Secondary button
```
border border-neutral-700 px-3 py-1.5 text-xs hover:bg-neutral-800
```

### Input / select
```
w-full border border-neutral-700 bg-neutral-900 px-3 py-1.5 text-sm
focus:outline-none focus:ring-1 focus:ring-neutral-500
```

### Nav link (sidebar / header)
- Inactive: `text-neutral-500 hover:bg-neutral-900 hover:text-neutral-100`
- Active: `bg-neutral-100 text-neutral-900` (inverted block, not an accent color)
- Padding `px-3 py-2`, square.

### Tabs (underline style)
Container: `flex flex-wrap gap-1 border-b border-neutral-800`
Each tab: `-mb-px border-b-2 px-3 py-1.5 text-sm font-medium`
- Active: `border-neutral-100 text-neutral-100`
- Inactive: `border-transparent text-neutral-500 hover:text-neutral-100`
Optional trailing count: `ml-2 font-mono text-xs text-neutral-500`.

### Modal / popover
```
border border-neutral-700 bg-neutral-900 p-3   (popover)
border border-neutral-800 bg-neutral-900 p-5   (modal, + max-h-[85dvh] flex flex-col)
```
Backdrop: `fixed inset-0 bg-black/40`. No shadow. Close via Escape and
backdrop-click.

### List / table
Rows separated by `divide-y divide-neutral-800` inside a
`border border-neutral-800` container. Row padding `px-3 py-2 text-sm`.

### Status dot
`h-2 w-2` (square), color by state (see Accents), `animate-pulse` while pending.

## Accents

Color is reserved for state. Never decorative, never brand.

| Meaning | Token |
|---------|-------|
| Success / done / connected | `green-400` text, `green-500` dot |
| In progress / running / primary action | `blue-400` text, `blue-600` button, `blue-400` dot |
| Warning / needs attention | `amber-400` text; `amber-600/30` border + `amber-600/10` fill for banners |
| Error / failed | `red-400` text, `red-400` dot |

Keep at most one accent per view drawing the eye. Body content stays neutral.

## Canvas / chart colors

Plot lines `#d4d4d4` on a `bg-neutral-950` field with a `border-neutral-800`
frame. Playhead / cursor in the accent that matches its meaning (`#f43f5e` for a
scrub head is fine). Axis labels `#737373`.

## Scrollbars

```css
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb {
  background-color: rgb(64 64 64);
  border: 2px solid transparent;
  background-clip: content-box;
}
html { scrollbar-color: rgb(64 64 64) transparent; scrollbar-width: thin; }
```
(Light theme: `rgb(212 212 212)` thumb.)

## Checklist

- [ ] No `rounded-*` visible (or global override in place)
- [ ] No `shadow-*`
- [ ] Every surface boundary is a neutral border
- [ ] Text, backgrounds, controls are `neutral-*` unless conveying state
- [ ] Section headings are uppercase `tracking-widest text-neutral-500`
- [ ] Numbers are `font-mono`
- [ ] Accent colors only on status/actions, one focal accent per view
- [ ] Enabled controls show pointer cursor; disabled ones are muted
