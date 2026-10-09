---
name: equilux-design-system
description: Equilux brand and UI design system for anything visual built for Equilux. Use whenever building or changing an Equilux web app, React or Tailwind component, landing or marketing page, dashboard, chart, banner, theme, logo placement, color, typography, spacing or dark mode, when reviewing UI for being on-brand or accessible, or when the user says "make it on-brand", "use the Equilux design system", "Equilux styling", or "update this project to the latest design system". Ships versioned design tokens (JSON, CSS, Tailwind), the brand spec, logo assets and generic UX/UI guidance.
---

# Equilux design system

The brand spec is `references/spec.md`. It is the single source of truth, and everything else in this skill applies it.
`tokens/` holds the same values as importable files, and `assets/logo/` holds the wordmark. Read only what the task
needs:

| Task | Read |
| --- | --- |
| Any UI or page work | This file, then `references/web-apps.md` |
| Landing or marketing page | `references/marketing-pages.md` |
| Dashboard, chart or data callout | `references/data-viz.md` |
| Forms, messages, navigation, loading states, copy | `references/ux-guidelines.md` |
| Contrast, focus, keyboard, status colors | `references/accessibility.md` |
| Logo, favicon, lockup | `references/logo.md` |
| An exact value or rule | `references/spec.md` (cite the § you used) |
| Catching a project up to a newer version | `references/changelog.md` |
| Before finishing any UI work | `references/review-checklist.md` |

If the project has its own `AGENTS.md`, `CLAUDE.md` or design docs, they take precedence over this skill where they
differ.

## Rules

1. **Never invent a color, font, size, spacing, radius or shadow.** Take every value from `tokens/` (CSS variables
   `--eqx-*`, the Tailwind preset or theme, or `tokens.json`). If a needed token doesn't exist, say so and propose an
   addition rather than using a one-off value. Open items are listed in spec §8, §10 and in the repository's
   `design-system/open-questions.md`. Never fill them in yourself.
2. **Build themed UI from semantic tokens**: `bg`, `surface`, `text`, `text-secondary`, `border`, `link`, `accent`,
   `highlight`. Never build it from palette tokens such as `navy-900` or `paper`. The `cta-*` button tokens are the
   one theme-invariant exception (spec §3.5). Support light and dark from the start; `tokens.css` already handles
   `prefers-color-scheme` and `data-theme`.
3. **Type:** use Space Grotesk for display and headings at 19px or larger, and Inter for body and UI. Use IBM Plex
   Mono only for genuinely data-like content. Use the §4.2 scale tokens and nothing between them.
4. **Shape and surface:** the look is flat. No gradients, glows or drop shadows. Use radius 4/8/16 for controls,
   cards and panels; pills only for small tags. Layer with `surface` on `bg` plus a `border` hairline. Dividers use
   the dashed motif (spec §6).
5. **Color discipline:** roughly 60% neutral, 30% navy and 10% green in light theme. Gold appears once per view at
   most. Never use gold or `green-400` as text on light grounds. In dark theme, small link or accent text on
   `surface` follows the §3.5 errata.
6. **Accessibility is not optional:** meet WCAG 2.2 AA as a minimum. Status is never shown by color alone. Every
   interactive element has a visible focus state. See `references/accessibility.md`.
7. **Voice and tone (§10) is unwritten.** Don't invent brand voice. Write plain, specific copy following
   `references/ux-guidelines.md`, and flag marketing copy for human review.

## Using the tokens in a project

Copy the four files from `tokens/` into the project's styles directory unedited. They are `tokens.css`,
`tokens.json`, `tailwind.preset.js` (Tailwind v3) and `tailwind-theme.css` (Tailwind v4). Import `tokens.css` once
globally, and load the fonts per spec §4.1. A project that needs an older version copies from
`design-system/build/<version>/` in the engineering-playbook repository instead. Never edit the copied files. To
change a value, change the spec (see below).

## Two modes

Each project records the design-system version it was last brought up to in `.equilux-design-version` at its root.
The file holds one line with a version such as `0.3.1`. The current version is in the header of `tokens/tokens.css`.

- **New project, or no file yet:** build to the current rules, then write the file with the current version.
- **The file holds an older version:** apply each `references/changelog.md` entry newer than it, oldest first.
  Search the project for each entry's "Find:" hints and change what matches. Then run the review checklist and
  update the file.

The changelog tells you what to *change*; only the spec and references say what to *build*.

## Changing the design system

The design system is versioned by spec file in the engineering-playbook repository. Each version is a file
`design-system/versions/X.Y.Z.md`. `python3 scripts/design-tokens.py` regenerates `tokens/`, the pinned builds and
`references/spec.md` from the highest version whose status is not `proposed`. Don't hand-edit generated files.
Details are in `design-system/README.md` in that repository.
