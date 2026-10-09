# Building Equilux web apps

How to apply the spec in a React, Tailwind or plain-CSS codebase. Values live in `../tokens/`; this file never
restates them. Section numbers (§) refer to `spec.md`.

## Setup

1. Copy `tokens.css` (and the Tailwind file for your version, if you use Tailwind) into the project unedited. Import
   `tokens.css` once at the root (`import './styles/tokens.css'` in the app entry, or `@import` in the global
   stylesheet).
2. Load Space Grotesk 500/600/700, Inter 400/500/600 and IBM Plex Mono 500 (§4.1). Self-host the woff2 files in
   production, and use `font-display: swap`.
3. Tailwind:
   - **v4:** `@import "tailwindcss"; @import "./tokens.css"; @import "./tailwind-theme.css";`
   - **v3:** `presets: [require('./tailwind.preset.js')]` in `tailwind.config.js`, plus the `tokens.css` import.
4. Without Tailwind, use the CSS variables directly (`var(--eqx-surface)`), or the generated type classes
   (`.eqx-type-heading-lg`).
5. Write `.equilux-design-version` with the version from the `tokens.css` header.

Tailwind names, which both outputs share:

| Spec token | Tailwind |
| --- | --- |
| Semantic colors `bg`, `surface`, `text`, `text-secondary`, `border`, `link`, `accent`, `highlight` | `bg-surface`, `text-text-secondary`, `border-border`, `text-link`, … |
| Button pair `cta-bg`, `cta-bg-hover`, `cta-text` | `bg-cta-bg`, `hover:bg-cta-bg-hover`, `text-cta-text` |
| Literal palette (`navy-900`, `paper`, …) | `eqx-navy-900`, `eqx-paper`. Use only for theme-invariant art such as the motif or print |
| `space-1` … `space-9` | `p-space-4`, `gap-space-5`, `mt-space-8` |
| `radius-sm/md/lg` | `rounded-sm`, `rounded-md`, `rounded-lg` (overrides Tailwind's defaults on purpose) |
| Fonts | `font-display`, `font-body`, `font-mono` |
| Type scale | `text-display-xl` … `text-data`; `label` also needs `uppercase` |

Because colors resolve through CSS variables, Tailwind opacity modifiers (`bg-text/10`) don't apply. Use the
`border` token for hairlines instead of inventing an alpha.

Don't keep Tailwind's default palette in use next to the brand. `bg-blue-500` or `text-gray-600` in an Equilux UI is
a defect. Only map onto an existing project palette when you're migrating, and say so.

## Theming

- Default to the OS theme. `tokens.css` switches on `prefers-color-scheme`. A manual toggle sets
  `data-theme="light"` or `data-theme="dark"` on `<html>` and stores the choice. Both are already wired in §11.1.
- Never branch on the theme in component code to pick colors. A component that only uses semantic tokens is correct
  in both themes automatically.
- Swap the logo on the same signal: Primary on light, Reversed on dark. Inline the SVG rather than using `<img>`;
  `logo.md` explains why and has the swap CSS, which must cover both the media query and `data-theme`.
- Charts and images follow the same rule. Pick from theme-aware tokens, not hardcoded literals.

## Layout

- Use spacing tokens only: no `p-[13px]` and no `margin: 10px`. The usual rhythm is `space-4` inside controls,
  `space-5`/`space-6` inside cards, `space-7`–`space-9` between page sections.
- Content max width is 1200px for app and wide layouts, and 720px for reading columns (§5). Center the container,
  with a side gutter of at least `space-4` on phones.
- Design mobile-first. Every screen must work at 320px wide with no horizontal scroll (except inside data tables,
  which scroll in their own container).

## Component recipes (§9)

These are written against semantic tokens, so each one works in both themes. Each shows plain CSS, with Tailwind in
the comment.

**Primary button.** Use one per view for the main action.

```css
.btn-primary {               /* bg-cta-bg text-cta-text hover:bg-cta-bg-hover rounded-sm px-space-5 py-space-3 font-body font-semibold */
  background: var(--eqx-cta-bg); color: var(--eqx-cta-text);
  border: 0; border-radius: var(--eqx-radius-sm);
  padding: var(--eqx-space-3) var(--eqx-space-5);
  font: 600 var(--eqx-text-body-md)/1 var(--eqx-font-body);
}
.btn-primary:hover { background: var(--eqx-cta-bg-hover); }
```

**Secondary button.** It has a `text`-colored 1.5px border and a transparent fill. On hover, the fill and label swap
to `text` on `bg`.

```css
.btn-secondary {             /* border-[1.5px] border-text text-text hover:bg-text hover:text-bg rounded-sm */
  background: transparent; color: var(--eqx-text);
  border: 1.5px solid var(--eqx-text); border-radius: var(--eqx-radius-sm);
}
.btn-secondary:hover { background: var(--eqx-text); color: var(--eqx-bg); }
```

**Focus**, for every interactive element. Until a focus token is approved, use `accent`, which clears the 3:1
non-text minimum on `bg` and `surface` in both themes.

```css
:focus-visible { outline: 2px solid var(--eqx-accent); outline-offset: 2px; }   /* focus-visible:outline-accent */
```

**Disabled.** Lower opacity on the whole control, `cursor: not-allowed` and `aria-disabled`. Don't add a new gray.

**Card.** Use `surface` on `bg` with a `border` hairline and `radius-md`. No shadow.

```css
.card { background: var(--eqx-surface); border: 1px solid var(--eqx-border); border-radius: var(--eqx-radius-md); padding: var(--eqx-space-5); }
```

**Inline link.** Use `link` with an underline. Body links stay underlined all the time; navigation links may
underline on hover. In dark theme on `surface`, links smaller than 24px (or 18.66px bold) use `text` and stay
underlined (the §3.5 errata).

**Inputs.** Use a `surface` fill, a 1px `border` that becomes 1px `text` on hover, and the focus ring above. Use
`radius-sm`, keep the label visible above the field, and put help or error text below it (see `ux-guidelines.md`).

**Divider.** Use a dashed rule, `border-top: 1px dashed var(--eqx-border)`, not a solid line.

**Tags and badges.** Small pills are the one allowed full radius. Use a `highlight` fill only for a single emphasis
per view, and remember gold is not a text color on light grounds.

**Data callouts.** Use the `data` type token (IBM Plex Mono) for numbers, units, deltas and coordinates. Pair a
delta's color with an arrow or sign, never color alone.

## Status colors (success, warning, error, info)

The current version defines no status colors. Proposals are pending in `design-system/versions/` in the playbook
repository. Until one is approved:

- Show status with an icon and a text label in `text` color, which already satisfies "not color alone".
- Don't introduce red, amber or blue values. If the user needs colored status now, say so and point them at the
  pending proposal.

## React specifics

- Put tokens in CSS, not in JS theme objects. If a library needs JS values (a chart, a canvas), read the computed
  CSS variable at runtime (`getComputedStyle(document.documentElement).getPropertyValue('--eqx-accent')`), or import
  `tokens.json` for theme-invariant literals.
- Component libraries (shadcn/ui, Radix, Headless UI) are fine. Map their CSS variables onto `--eqx-*` semantic
  tokens in one place, and remove their default shadows and radii.
- Icons: no icon set has been chosen yet. Use one line-icon family consistently within a project, and note the
  choice so it can become a spec decision.
