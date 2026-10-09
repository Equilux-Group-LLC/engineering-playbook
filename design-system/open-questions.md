# Open questions

Every unresolved design-system decision lives here and only here. Other files link to this list instead of restating
it. Delete an item once a spec version answers it.

Agents: never fill one of these in yourself. If a task needs one, stop and ask, or draft a proposal as a new
`versions/X.Y.Z.md` with `status: proposed`.

## Awaiting review

- **Approve or amend 0.4.0** (`versions/0.4.0.md`, proposed). It covers status colors, focus ring, chart palette,
  motion, a dark-theme link token for `surface`, a destructive button, and four new literal colors (`gold-700`,
  `red-600`, `red-400`, `navy-300`).

## Logo (spec §8)

- The clear-space rule. A suggested starting point is the cap-height of "e" on all sides, but it isn't confirmed.
- Minimum display sizes for favicon and app icon, the header lockup, and print.
- A stacked lockup for square or tall placements.
- A one-color version (all-navy or all-white) for single-color print and very small sizes.
- Outlined SVGs. The current SVGs set "equilu" as live text in Space Grotesk. Anywhere an SVG is loaded as an image
  (`<img>`, CSS backgrounds, email, documents), browsers fall back to a system font. Convert the text to paths.
- Ratifying the icon mark. The website's favicon and app icons (the gold X and rule-and-dot on navy) are in use but
  aren't in the spec.

## Voice and tone (spec §10)

- All of §10 is unwritten: personality, voice principles, tone by context (including when to use the first-person
  founder voice versus the company voice), vocabulary, and example rewrites.

## UI

- The icon family. 0.4.0 proposes the rules (one outline family, 1.5–2px stroke, 16/20/24px) but not which family.
- A diverging chart scale, for data with a meaningful midpoint.
- The elevation policy for overlays. The system is flat with no shadows; menus, popovers and modals still need a
  separation rule (border only, or a defined overlay scrim).
