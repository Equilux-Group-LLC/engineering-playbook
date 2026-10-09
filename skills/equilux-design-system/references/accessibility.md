# Accessibility

Equilux UIs meet **WCAG 2.2 AA** at a minimum and aim for AAA on body text where the palette allows. The spec's
measured contrast tables are the authority for color pairs: §3.3 for the light palette and §3.5 for dark theme and
its errata. Use a pair the tables list as passing for its use. A pair the tables don't list needs measuring before
it ships.

## Color and contrast

| Content | Minimum ratio |
| --- | --- |
| Body text and small text | 4.5 : 1 |
| Large text (24px, or 18.66px bold) | 3 : 1 |
| UI component boundaries, focus indicators, icons and chart marks that carry meaning | 3 : 1 against adjacent colors |

The spec's known limits:

- On light grounds, `gold-500` and `green-400` are decorative only, never text (§3.3).
- In dark theme, `green-600` is never a foreground color (§3.5).
- In dark theme on `surface`, link and accent text smaller than large text uses `text` with an underline (§3.5
  errata).
- Text over the motif or photography sits on a solid area, or over a texture faint enough that the pair still
  measures.

## Never color alone

Status, validation, deltas, chart series and links each need a second cue:

- **Status and validation:** an icon and a text word ("Error", "Saved"), plus the color.
- **Links in body text:** an underline.
- **Chart series:** direct labels, or distinct markers or patterns.
- **Deltas:** an arrow or sign, plus the number.

## Keyboard and focus

- Everything that works by pointer works by keyboard, in a logical tab order. There are no keyboard traps, and
  modals return focus to their trigger when they close.
- Every interactive element shows a visible `:focus-visible` indicator: a 2px `accent` outline offset by 2px (see
  `web-apps.md`). Never remove outlines without a replacement.
- Focused elements aren't hidden behind sticky headers or action bars. Use `scroll-padding` (WCAG 2.2 2.4.11).
- Provide a "Skip to content" link on pages with navigation.

## Targets and input

- Interactive targets are at least 44×44px, with spacing between them, including in desktop layouts. Pad the hit
  area when the visual element has to be smaller.
- Don't rely on hover alone. Anything revealed on hover is also reachable by focus and tap.
- Dragging always has a non-drag alternative (WCAG 2.2 2.5.7).

## Text and layout

- Body text is never smaller than `body-sm` (14px), and 16px is the default. Never set Space Grotesk below 19px
  (§4.3).
- The layout works at 320px wide and at 200% zoom without losing content, and text spacing can be increased without
  clipping.
- Use relative units for type (the tokens are rem). Don't cap line length below what the reader chose.

## Semantics

- Use real elements: `<button>` for actions, `<a href>` for navigation, `<label for>` on every field, one `h1`, and
  headings in order.
- Use landmarks: `header`, `nav`, `main` and `footer`.
- Give images meaningful `alt` text, and `alt=""` plus `aria-hidden` on decorative motif SVGs.
- Charts have an accessible name and a text or table alternative.
- Dynamic messages use `role="status"` or `role="alert"`, and form errors are linked with `aria-describedby`.
- Respect `prefers-reduced-motion` and `prefers-color-scheme`. The tokens already handle the second.

## Checking

- Measure any new color pair with a WCAG contrast tool before it ships, and add it to the spec's table in the next
  version.
- Run an automated audit (axe or Lighthouse) and fix every violation. Then tab through the page and test it with a
  screen reader (VoiceOver), in both themes.
