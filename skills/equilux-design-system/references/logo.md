# Logo and mark

The full specification is `spec.md` §8. Assets are in `../assets/logo/`.

## The wordmark

"equilu" is set in Space Grotesk 600, followed by a custom X made of two crossing rounded gold bars, which reads as
"equiluX". A rule runs beneath the whole wordmark with a gold dot centered on it, like a fulcrum. Never retype,
redraw, recolor or rearrange it. Use the asset files.

| Version | File | Use on |
| --- | --- | --- |
| Primary | `logo-primary.svg` | Light grounds, wherever `bg` is `paper` |
| Reversed | `logo-reversed.svg` | Dark grounds, wherever `bg` is `navy-900` |

`logo-primary.png` and `logo-reversed.png` are 1440×960 presentation boards: the mark centered on its own `paper`
or `navy-900` ground. Use them as they are for slides, documents and social images on a matching ground. They are
not header logos, and you must not crop them.

**Font dependency.** The SVGs draw "equilu" as live text in Space Grotesk. Browsers render an SVG loaded through
`<img>`, `<picture>` or a CSS background in isolation, without the page's web fonts, so the word falls back to a
system font and the mark breaks. Until outlined SVGs exist (`design-system/open-questions.md`), **inline the SVG**
into a page that loads Space Grotesk. Inline SVG uses the page's fonts. In React, paste the SVG markup into a
component and keep the `role="img"`, `aria-label` and `<title>`.

Swap Primary and Reversed on the same theme signal as the rest of the UI (`web-apps.md` → Theming). A CSS-only swap
renders both inline SVGs and hides one; it must cover both the OS preference and a manual `data-theme`:

```css
.logo-reversed { display: none; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) .logo-primary { display: none; }
  :root:not([data-theme="light"]) .logo-reversed { display: inline; }
}
:root[data-theme="dark"] .logo-primary { display: none; }
:root[data-theme="dark"] .logo-reversed { display: inline; }
```

Give the hidden copy `aria-hidden="true"`, or swap them in JS, so screen readers announce "Equilux" once.

## Icons

`favicon.svg`, `apple-touch-icon.png`, `icon-192.png` and `icon-512.png` are the icons currently used on the Equilux
website. They show the gold X and the rule-and-dot on navy. They are in use but not yet ratified in the spec, and
neither are minimum sizes. Use them as they are for favicons and web-app manifests, and don't derive new icon
variants.

## Not defined yet: don't invent

The spec leaves these open (§8):

- an exact clear-space rule
- minimum display sizes (favicon, header, print)
- a stacked lockup for square or tall placements
- a one-color version

Until they're set:

- Use the horizontal lockup only, at a comfortably legible size (header height of about 24–40px on screen), with
  generous space around it.
- Never squeeze it into a square slot. Use the icon for those.
- If a placement needs one of the open items, such as letterhead, business cards or a single-color print, stop and
  ask instead of improvising.

## Don'ts

- Don't recolor any part: no green X, and no gold "equilu".
- Don't add effects such as shadow, outline, glow or gradient.
- Don't stretch, rotate, crop the rule, or separate the X from the word.
- Don't place it on busy photography or on mid-tone grounds where neither version has clear contrast.
- Don't use it as a motif element, or the motif as a logo (§6).
