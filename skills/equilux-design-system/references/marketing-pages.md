# Equilux landing and marketing pages

Applies the spec to public pages: the website, campaign pages and banners. Section numbers (§) refer to `spec.md`.
Values live in `../tokens/`.

## Character

The brand pillars (§1) decide every call here: **balance**, **analog ↔ digital**, **data/geospatial pedigree** and
**quiet confidence**. In practice that means:

- Use generous whitespace and few elements per screen. When in doubt, remove something.
- Make composition symmetric where it's sensible, such as a centered hero or an evenly split two-column block.
- Typography should look precise and engineered, on a warm `paper` ground rather than stark white.
- Avoid startup clichés: gradients, glows, glassmorphism, floating 3D blobs, emoji bullets, and "Revolutionize your…"
  headlines.

## Page structure

| Element | Guidance |
| --- | --- |
| Width | 1200px outer container; long-form prose at 720px (§5) |
| Vertical rhythm | `space-8` to `space-9` between sections; `space-6` to `space-7` between a heading and its content |
| Hero | Use `display-xl` (`display-lg` on phones) in Space Grotesk in `text` color, one supporting sentence in `body-lg` `text-secondary`, and at most one primary CTA plus one secondary. A motif background is optional |
| Section headings | `heading-lg`; an optional `label` eyebrow above it in `text-secondary` |
| Body | `body-lg` for marketing prose, `body-md` for dense content; line length ≤ 75 characters |
| Stats and proof points | A number in the `data` style (IBM Plex Mono) with a short Inter caption. At most 3–4 in a row |
| Dark sections | A whole band can switch to the dark pairing with `data-theme="dark"` on the section. Semantic tokens then flip locally, and the Reversed logo is used inside it |

Alternate `bg` and `surface` bands, or set one dark band, to separate sections. Don't use color washes or gradient
transitions.

## The motif (§6)

The brand's graphic language comes from the quarter-globe asset.

- **Dashed lat/long grid:** use it as a background texture, a section divider or an overlay at 10–20% opacity over
  navy or paper. Draw it as inline SVG with `stroke-dasharray` so it scales cleanly. A grid in `gold-500` or
  `green-600` over a `navy-900` field works for a feature band.
- **Quarter and partial circle crops:** crop arcs at the frame edge for section backgrounds and image masks, giving
  "a partial view of something larger".
- **Flat only:** no shading, gradients or glows on any motif element.
- The motif and the logo are separate languages. They don't need to appear together, and the motif never stands in
  for the logo.
- The motif is decorative: give its SVG `aria-hidden="true"` and keep it from reducing text contrast. Put text on a
  solid area, or keep the grid at the low end of its opacity range behind text.

## Imagery (§7)

- Use natural light and real working contexts. Avoid staged stock poses and warm or saturated stock photography.
- A duotone in `navy-900`/`paper` is acceptable and fits the flat graphic language.
- Every meaningful image needs useful `alt` text, and decorative images get `alt=""`.
- Serve responsive sizes (`srcset`) in modern formats, and lazy-load anything below the fold.

## Color on a page

Aim for roughly 60% neutral, 30% navy and 10% green in light sections (§3.2). Gold appears once per page area: a
badge, an underline or one icon. Primary CTAs use the `cta-*` pair everywhere, including on dark bands.

## Copy

Voice and tone (§10) are not written yet. Until they are:

- Keep copy short, specific and concrete. Lead with the outcome for the reader.
- Don't invent taglines, a brand personality or "voice" flourishes. Use the user's supplied copy, and mark any
  placeholder copy clearly as a placeholder for human review.
- Use sentence case for headings and buttons.

## Performance and accessibility

- Keep total font weight small: load only the weights in §4.1, and preload the hero's display font.
- Aim for Core Web Vitals in the "good" range. Reserve image dimensions to avoid layout shift.
- Use one `h1` per page and keep heading order intact. The hero CTA must be a real `<a>` or `<button>`.
- Check the page in both themes and at 320px wide before calling it done (`review-checklist.md`).
