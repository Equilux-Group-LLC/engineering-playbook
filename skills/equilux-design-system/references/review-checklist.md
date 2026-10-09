# Equilux UI review checklist

Work through this before calling UI work finished or opening a PR that changes UI. Report anything you couldn't
check. Details are in the other files in this directory.

## Tokens

- [ ] Every color, size, space, radius and font comes from the tokens (`--eqx-*`, the Tailwind preset or theme).
  There are no hex literals or arbitrary values (`p-[13px]`, `#333`) in components.
- [ ] Themed UI uses semantic tokens. Literal palette tokens appear only in theme-invariant art.
- [ ] No Tailwind or framework default colors (`blue-500`, `gray-600`) remain in Equilux UI.
- [ ] The token files are unedited copies of one version, and `.equilux-design-version` names that version.
- [ ] Anything missing from the tokens was raised as a proposal, not invented.

## Look

- [ ] Space Grotesk only at 19px or larger, Inter for body and UI, IBM Plex Mono only for data.
- [ ] Type uses the §4.2 scale tokens only.
- [ ] Flat: no gradients, glows or drop shadows. Layering is `surface` + `border`.
- [ ] Radius 4/8/16 by role. Pills only on small tags and badges.
- [ ] Gold appears at most once per view, and never as text on light grounds.
- [ ] Dividers use the dashed motif. The motif is decorative and `aria-hidden`.
- [ ] The logo is the asset file (Primary on light, Reversed on dark), unaltered, in the horizontal lockup.

## Themes and layout

- [ ] Correct in light and dark (OS setting) and with `data-theme` forced each way.
- [ ] Dark-theme link or accent text on `surface` follows the §3.5 errata.
- [ ] Works at 320px wide with no horizontal page scroll, and at 200% zoom.
- [ ] Content widths are 1200px (wide) or 720px (reading), with spacing tokens for the rhythm.

## Accessibility

- [ ] Contrast meets the table in `accessibility.md`, and every new pair was measured.
- [ ] Status, validation, deltas and chart series are never shown by color alone.
- [ ] Every interactive element has a visible `:focus-visible` indicator and is reachable by keyboard in a logical
  order.
- [ ] Targets are at least 44×44px. Nothing is reachable by hover only.
- [ ] Semantic HTML: one `h1`, ordered headings, landmarks, labels and alt text.
- [ ] An automated audit (axe or Lighthouse) shows no violations.

## Behavior

- [ ] Every screen and flow has a way out (Back, Cancel or Close).
- [ ] Undo or deferred commit is used instead of "Are you sure?", except for actions that are truly destructive.
- [ ] Error messages say what happened, what it means and what to do. Errors don't auto-dismiss, and messages never
  stack.
- [ ] Forms have visible labels, inline errors plus a summary banner, and keep the user's input.
- [ ] Loading feedback follows the timing table, and `prefers-reduced-motion` is respected.
- [ ] Healthy states are quiet. Exceptions are what stand out.

## Copy

- [ ] Sentence case and verb-led button labels.
- [ ] No invented brand voice or taglines. Placeholder copy is marked for human review.
